extends GutTest
## AnimationTree state machine driven by sim views (context F5): 1:1 states, attack clips
## stretched to the sim length, frozen during hitstop, combo hits restart the clip.

const CLIPS := ["Idle", "Running_A", "Jump_Idle", "Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Kick",
	"Hit_A", "Hit_B", "Blocking", "Death_A", "Cheer"]


func _player() -> AnimationPlayer:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var player := AnimationPlayer.new()
	holder.add_child(player)
	var lib := AnimationLibrary.new()
	for n: String in CLIPS:
		var a := Animation.new()
		a.length = 1.0
		lib.add_animation(n, a)
	player.add_animation_library("", lib)
	return player


func _animator(config: GameConfig = null) -> CharacterAnimator:
	var player := _player()
	var anim := CharacterAnimator.new()
	player.get_parent().add_child(anim)
	anim.setup(player, config if config != null else GameConfig.new())
	return anim


func _v(state: int, on_ground: bool = true, kind: int = 0, hitstop: int = 0) -> Dictionary:
	return {"state": state, "on_ground": on_ground, "attack_kind": kind, "item_kind": Fighter.NONE,
		"charge_ticks": 0, "hitstop_ticks": hitstop}


func test_follows_sim_states() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.MOVE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.RUN)
	assert_eq(a.clip_for(AnimMap.Anim.RUN), "Running_A")
	a.apply(_v(Fighter.State.HITSTUN, false), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.LAUNCHED)


func test_every_anim_has_a_state_machine_node() -> void:
	var a := _animator()
	for anim: int in AnimMap.Anim.values():
		assert_true(a.state_machine().has_node(AnimMap.anim_name(anim)), AnimMap.anim_name(anim))


func test_attack_clips_stretch_to_the_sim_length() -> void:
	var c := GameConfig.new()
	var a := _animator(c)
	var node := a.state_machine().get_node("HEAVY") as AnimationNodeAnimation
	assert_true(node.use_custom_timeline)
	assert_true(node.stretch_time_scale)
	var heavy := AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY)
	assert_almost_eq(node.timeline_length, float(heavy.total_ticks()) / SimTime.TICK_RATE, 0.0001)
	assert_almost_eq(CharacterAnimator.timed_seconds(AnimMap.Anim.HEAVY, c), node.timeline_length, 0.0001)


func test_hitstop_freezes_the_animation() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.05)
	var before := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 3), 0.05)
	assert_almost_eq(a.play_position(), before, 0.0001, "no progress during hitstop")
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.05)
	assert_gt(a.play_position(), before)


func test_next_combo_hit_restarts_the_clip() -> void:
	var a := _animator()
	for i: int in 5:
		a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1), 0.03)
	var mid := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_2), 0.0)
	assert_lt(a.play_position(), mid, "LIGHT_2 starts the punch again")


func test_forced_cheer_overrides_the_view_and_ignores_a_frozen_hitstop() -> void:
	var a := _animator()
	a.force(AnimMap.Anim.CHEER)
	for i: int in 3:  # travel settles into the new state over a couple of frames
		a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 5), 0.05)
	assert_eq(a.current_anim(), AnimMap.Anim.CHEER)
	assert_eq(a.clip_for(AnimMap.Anim.CHEER), "Cheer")
	var before := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 5), 0.05)
	assert_gt(a.play_position(), before, "the match froze mid-hitstop, the cheer still plays")
	a.force(-1)
	a.apply(_v(Fighter.State.MOVE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.RUN, "back on the sim view")
