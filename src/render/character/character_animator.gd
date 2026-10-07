class_name CharacterAnimator
extends Node
## AnimationTree state machine built in code (design.md GD-ANIM-01, context F5). One node per
## AnimMap.Anim; every pair is linked with a short crossfade. The tree runs in manual mode:
## apply() advances it by the frame delta, or not at all during hitstop. Swings and poses
## (combat-motion A2) are SeekNodes placed every frame by a SwingDriver: each style swings its
## own clip with the strike on the sim's first active tick. They come in two copies (NAME and
## NAME_B) used in turn, so one combo hit crossfades into the next instead of popping.

const XFADE_SECONDS := 0.08
## Into a swing (fast, the windup is short) and out of a swing's follow-through back to rest.
const SWING_IN_SECONDS := 0.05
const SWING_OUT_SECONDS := 0.14
const ALT_SUFFIX := "_B"
## View states a toss may play over (anything else, e.g. getting hit, cuts it short).
const STANDING: Array[int] = [AnimMap.Anim.IDLE, AnimMap.Anim.RUN, AnimMap.Anim.JUMP]

var _tree: AnimationTree
var _machine: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _clips: Dictionary = {}
var _default_clips: Dictionary = {}
var _player: AnimationPlayer
var _current: int = -1
var _last_kind: int = -1
## A state played regardless of the sim view (force()); -1 follows the view.
var _forced: int = -1
var _driver: SwingDriver
## The sim's throw hit was seen (toss()); used up by the next apply().
var _toss_asked: bool = false
## Machine node playing the current seek-driven state ("" while a plain clip plays).
var _seek_state: String = ""


func setup(player: AnimationPlayer, config: GameConfig) -> void:
	var available := PackedStringArray()
	for n: StringName in player.get_animation_list():
		available.append(String(n))
	_player = player
	_clips = AnimClips.resolve(available)
	_default_clips = _clips.duplicate()
	_driver = SwingDriver.new(config)
	_machine = AnimationNodeStateMachine.new()
	for anim: int in AnimMap.Anim.values():
		_machine.add_node(AnimMap.anim_name(anim), _node_for(anim, player))
		if seeks(anim):
			_machine.add_node(AnimMap.anim_name(anim) + ALT_SUFFIX, SeekNode.build(String(_clips[anim])))
	_link_all()
	_tree = AnimationTree.new()
	player.get_parent().add_child(_tree)
	_tree.tree_root = _machine
	_tree.anim_player = _tree.get_path_to(player)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	for n: StringName in _machine.get_node_list():
		if _machine.has_node(n) and _machine.get_node(n) is AnimationNodeBlendTree:
			SeekNode.freeze(_tree, String(n))
	_enter(AnimMap.Anim.IDLE, {})
	_tree.advance(0.0)


func apply(view: Dictionary, delta: float) -> void:
	var anim := _forced if _forced >= 0 else AnimMap.anim_for(view)
	if _forced < 0 and _tossing(anim, view):
		anim = AnimMap.Anim.THROW
	var kind := int(view["attack_kind"])
	if anim != _current or (AnimMap.is_timed(anim) and (kind != _last_kind or _driver.restarts(view))):
		_enter(anim, view)
	_last_kind = kind
	var frozen := _forced < 0 and int(view["hitstop_ticks"]) > 0  # a frozen final hit still cheers
	if _seek_state.is_empty():
		_tree.advance(0.0 if frozen else delta)
		return
	# the driver holds a seek node still through hitstop; the tree keeps blending into it
	SeekNode.seek(_tree, _seek_state, _driver.time(view, delta, frozen))
	_tree.advance(delta)


## Swings (timed attack states), the toss and poses are placed by the SwingDriver, not played.
static func seeks(anim: int) -> bool:
	return AnimMap.is_timed(anim) or SwingClips.POSES.has(anim) or anim == AnimMap.Anim.THROW


## The sim throws in one tick (HOLDING -> standing, frozen in the throw's hitstop): the toss
## plays from the throw event (toss()), or from that frozen frame if the event was missed, until
## its follow-through ends or the fighter does something else.
func _tossing(anim: int, view: Dictionary) -> bool:
	var asked := _toss_asked
	_toss_asked = false
	if not STANDING.has(anim):
		return false
	if asked or (_current == AnimMap.Anim.HOLD and int(view["hitstop_ticks"]) > 0):
		return _current != AnimMap.Anim.THROW or _driver.done()
	return _current == AnimMap.Anim.THROW and not _driver.done()


## This fighter just threw someone (the sim's "hit" with attack_kind THROW): toss on the next frame.
func toss() -> void:
	_toss_asked = true


func force(anim: int) -> void:
	_forced = anim


func current_anim() -> int:
	return _current


func clip_for(anim: int) -> String:
	return String(_clips[anim])


## Swaps the clip a looping state plays (a style's idle, StyleGear). Swings and poses pick their
## own clips. False (and nothing changes) if the state is seek-driven or the clip missing.
func set_clip(anim: int, clip: String) -> bool:
	if seeks(anim) or not _player.has_animation(clip):
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


## The clip the current swing / pose plays ("" for a plain state).
func seek_clip() -> String:
	return SeekNode.clip_of(_machine.get_node(_seek_state) as AnimationNodeBlendTree) if not _seek_state.is_empty() else ""


func _enter(anim: int, view: Dictionary) -> void:
	var name := AnimMap.anim_name(anim)
	if seeks(anim):
		name = name + ALT_SUFFIX if _seek_state == name else name  # the other copy: blend, no pop
		var fallback := String(_clips[anim])
		var length := _player.get_animation(fallback).length if _player.has_animation(fallback) else 1.0
		var clip := _driver.begin(anim, view, fallback, length, _player.has_animation)
		SeekNode.set_clip(_machine.get_node(name) as AnimationNodeBlendTree, clip)
		_seek_state = name
	else:
		_seek_state = ""
	if _current == -1:
		_playback.start(name, true)
	else:
		_playback.travel(name)
	_current = anim


## Every node to every other, timed by what is blending into what.
func _link_all() -> void:
	var names := _machine.get_node_list().filter(func(n: StringName) -> bool: return n != &"Start" and n != &"End")
	for a: StringName in names:
		for b: StringName in names:
			if a == b:
				continue
			var t := AnimationNodeStateMachineTransition.new()
			var from_swing := _machine.get_node(a) is AnimationNodeBlendTree
			var into_swing := _machine.get_node(b) is AnimationNodeBlendTree
			t.xfade_time = SWING_IN_SECONDS if into_swing else (SWING_OUT_SECONDS if from_swing else XFADE_SECONDS)
			_machine.add_transition(a, b, t)


func _node_for(anim: int, player: AnimationPlayer) -> AnimationRootNode:
	var clip := String(_clips[anim])
	if seeks(anim):
		return SeekNode.build(clip)
	var node := AnimationNodeAnimation.new()
	node.animation = StringName(clip)
	node.use_custom_timeline = true
	node.timeline_length = player.get_animation(clip).length if player.has_animation(clip) else 1.0
	node.stretch_time_scale = false
	node.loop_mode = Animation.LOOP_LINEAR if AnimClips.loops(anim) else Animation.LOOP_NONE
	return node
