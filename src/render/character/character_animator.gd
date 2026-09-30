class_name CharacterAnimator
extends Node
## AnimationTree state machine built in code (design.md GD-ANIM-01, context F5). One node per
## AnimMap.Anim; every pair is linked with a short crossfade. The tree runs in manual mode:
## apply() advances it by the frame delta, or not at all during hitstop. Attack clips use a
## custom timeline stretched to the sim attack length, so the swing lines up with the hitbox.

const XFADE_SECONDS := 0.08

var _tree: AnimationTree
var _machine: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _clips: Dictionary = {}
var _default_clips: Dictionary = {}
var _player: AnimationPlayer
var _current: int = -1
var _last_kind: int = -1


func setup(player: AnimationPlayer, config: GameConfig) -> void:
	var available := PackedStringArray()
	for n: StringName in player.get_animation_list():
		available.append(String(n))
	_player = player
	_clips = AnimClips.resolve(available)
	_default_clips = _clips.duplicate()
	_machine = AnimationNodeStateMachine.new()
	for anim: int in AnimMap.Anim.values():
		_machine.add_node(AnimMap.anim_name(anim), _node_for(anim, player, config))
	for a: int in AnimMap.Anim.values():
		for b: int in AnimMap.Anim.values():
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = XFADE_SECONDS
				_machine.add_transition(AnimMap.anim_name(a), AnimMap.anim_name(b), t)
	_tree = AnimationTree.new()
	player.get_parent().add_child(_tree)
	_tree.tree_root = _machine
	_tree.anim_player = _tree.get_path_to(player)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_enter(AnimMap.Anim.IDLE)
	_tree.advance(0.0)


func apply(view: Dictionary, delta: float) -> void:
	var anim := AnimMap.anim_for(view)
	var kind := int(view["attack_kind"])
	if anim != _current or (AnimMap.is_timed(anim) and kind != _last_kind):
		_enter(anim)
	_last_kind = kind
	_tree.advance(0.0 if int(view["hitstop_ticks"]) > 0 else delta)


func current_anim() -> int:
	return _current


func clip_for(anim: int) -> String:
	return String(_clips[anim])


## Swaps the clip a looping state plays (a style's idle, StyleGear). Timed attack states keep
## their sim-stretched clips. False (and nothing changes) if the state is timed or the clip missing.
func set_clip(anim: int, clip: String) -> bool:
	if AnimMap.is_timed(anim) or not _player.has_animation(clip):
		push_warning("CharacterAnimator: cannot play %s for %s" % [clip, AnimMap.anim_name(anim)])
		return false
	var node := _machine.get_node(AnimMap.anim_name(anim)) as AnimationNodeAnimation
	node.animation = StringName(clip)
	node.timeline_length = _player.get_animation(clip).length
	_clips[anim] = clip
	return true


## Back to the clip AnimClips picked at setup.
func reset_clip(anim: int) -> void:
	if _clips[anim] != _default_clips[anim]:
		set_clip(anim, String(_default_clips[anim]))


func play_position() -> float:
	return _playback.get_current_play_position()


func state_machine() -> AnimationNodeStateMachine:
	return _machine


static func timed_seconds(anim: int, config: GameConfig) -> float:
	var attacks := AttackSet.from_config(config)
	var kind := AttackSet.Kind.LIGHT_1
	match anim:
		AnimMap.Anim.HEAVY:
			kind = AttackSet.Kind.HEAVY
		AnimMap.Anim.BAT:
			kind = AttackSet.Kind.BAT
		AnimMap.Anim.GRAB:
			kind = AttackSet.Kind.GRAB
	return float(attacks.get_attack(kind).total_ticks()) / SimTime.TICK_RATE


func _enter(anim: int) -> void:
	var name := AnimMap.anim_name(anim)
	if AnimMap.is_timed(anim) or _current == -1:
		_playback.start(name, true)  # swings restart from frame 0, no blend
	else:
		_playback.travel(name)
	_current = anim


func _node_for(anim: int, player: AnimationPlayer, config: GameConfig) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	var clip := String(_clips[anim])
	node.animation = StringName(clip)
	node.use_custom_timeline = true
	if AnimMap.is_timed(anim):
		node.timeline_length = timed_seconds(anim, config)
		node.stretch_time_scale = true
		node.loop_mode = Animation.LOOP_NONE
	else:
		node.timeline_length = player.get_animation(clip).length if player.has_animation(clip) else 1.0
		node.stretch_time_scale = false
		node.loop_mode = Animation.LOOP_LINEAR if AnimClips.loops(anim) else Animation.LOOP_NONE
	return node
