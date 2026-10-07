extends GutTest
## AnimationTree state machine driven by sim views (context F5): 1:1 states, swings placed by
## the sim attack ticks (combat-motion A2), frozen during hitstop, combo hits restart the clip.

const CLIPS := ["Idle", "Running_A", "Jump_Idle", "Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B",
	"Unarmed_Melee_Attack_Kick", "1H_Melee_Attack_Slice_Diagonal", "Dualwield_Melee_Attack_Stab",
	"Hit_A", "Hit_B", "Blocking", "Death_A", "Cheer", "Throw", "2H_Melee_Attack_Spinning"]


func _player() -> AnimationPlayer:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var player := AnimationPlayer.new()
	holder.add_child(player)
	var lib := AnimationLibrary.new()
	for n: String in CLIPS:
		var a := Animation.new()
		a.length = 2.0
		lib.add_animation(n, a)
	player.add_animation_library("", lib)
	return player


func _animator(config: GameConfig = null) -> CharacterAnimator:
	var player := _player()
	var anim := CharacterAnimator.new()
	player.get_parent().add_child(anim)
	anim.setup(player, config if config != null else GameConfig.new())
	return anim


func _v(state: int, on_ground: bool = true, kind: int = 0, hitstop: int = 0, ticks: int = 1,
		style: String = StyleCatalog.CLASSIC) -> Dictionary:
	return {"state": state, "on_ground": on_ground, "attack_kind": kind, "item_kind": Fighter.NONE,
		"charge_ticks": 0, "hitstop_ticks": hitstop, "attack_ticks": ticks, "style": style, "special": ""}


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


func test_swings_and_poses_are_seek_nodes_in_two_copies() -> void:
	var a := _animator()
	for anim: int in [AnimMap.Anim.LIGHT, AnimMap.Anim.HEAVY, AnimMap.Anim.GRAB, AnimMap.Anim.HOLD]:
		var name := AnimMap.anim_name(anim)
		assert_true(a.state_machine().get_node(name) is AnimationNodeBlendTree, name)
		assert_true(a.state_machine().has_node(name + CharacterAnimator.ALT_SUFFIX), name)
	assert_true(a.state_machine().get_node("RUN") is AnimationNodeAnimation)


func test_the_strike_lands_on_the_first_active_tick() -> void:
	var c := GameConfig.new()
	var a := _animator(c)
	var light := AttackSet.from_config(c).get_attack(AttackSet.Kind.LIGHT_1)
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 0, 1), 0.0)
	assert_eq(a.seek_clip(), "Unarmed_Melee_Attack_Punch_A")
	assert_almost_eq(a.play_position(), float(SwingClips.JAB["start"]), 0.001, "starts cocked")
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 0, light.startup_ticks + 1), 0.0)
	assert_almost_eq(a.play_position(), float(SwingClips.JAB["contact"]), 0.001, "fist out on the hit")


func test_each_style_swings_its_own_clip() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 0, 1, StyleCatalog.WEAPON), 0.0)
	assert_eq(a.seek_clip(), "1H_Melee_Attack_Slice_Diagonal", "the knight slashes")
	a.apply(_v(Fighter.State.IDLE), 0.1)
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.GRAB), 0.0)
	assert_eq(a.seek_clip(), "Dualwield_Melee_Attack_Stab", "a grab reaches with both hands")


func test_holding_a_fighter_holds_the_reaching_pose() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.HOLDING), 0.0)
	assert_eq(a.current_anim(), AnimMap.Anim.HOLD)
	assert_eq(a.seek_clip(), "Dualwield_Melee_Attack_Stab")
	for i: int in 10:
		a.apply(_v(Fighter.State.HOLDING), 0.05)
		assert_almost_eq(a.play_position(), 0.72, 0.05, "arms stay out, only a small sway")


func test_the_getup_attack_spins_on_the_sim_getup_ticks() -> void:
	var c := GameConfig.new()
	var a := _animator(c)
	var v := _v(Fighter.State.GETUP)
	v["getup"] = "attack"
	v["getup_ticks"] = 1
	a.apply(v, 0.016)
	assert_eq(a.seek_clip(), String(SwingClips.GETUP_SWEEP["clip"]), "a radial hit reads as a spin")
	v["getup_ticks"] = Getup.attack_of(c).startup_ticks + 1
	a.apply(v, 0.0)
	assert_almost_eq(a.play_position(), float(SwingClips.GETUP_SWEEP["contact"]), 0.001, "on the active tick")


func test_a_rollback_rewinding_a_few_ticks_does_not_restart_the_swing() -> void:
	var a := _animator()
	for t: int in range(1, 12):
		a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, t), 0.016)
	var before := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, 9), 0.016)
	assert_gt(a.play_position(), float(SwingClips.KICK["start"]) + 0.01, "still mid-kick")
	assert_lt(a.play_position(), before, "just steps back with the rewound tick")


func test_combo_hits_alternate_copies_so_they_blend() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_1, 0, 1), 0.0)
	var first := a.seek_clip()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.LIGHT_2, 0, 1), 0.0)
	assert_ne(a.seek_clip(), first, "the hook is not the jab again")
	assert_eq(a.current_anim(), AnimMap.Anim.LIGHT)


func test_hitstop_freezes_the_animation() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, 3), 0.01)
	var before := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 3, 3), 0.05)
	assert_almost_eq(a.play_position(), before, 0.0001, "no progress during hitstop")
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, 4), 0.016)
	assert_gt(a.play_position(), before)


func test_next_combo_hit_restarts_the_clip() -> void:
	var a := _animator()
	for i: int in 8:
		a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, i + 1), 0.016)
	var mid := a.play_position()
	a.apply(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY, 0, 1), 0.0)
	assert_lt(a.play_position(), mid, "a fresh heavy right after the last starts the kick again")


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
