extends GutTest
## Event cues on the animator (polish-pass 7): a throw plays the toss, every hit replays the
## flinch (heavy hits rock harder), and a cue never fires late.

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


func test_a_throw_out_of_a_hold_plays_the_throw_then_returns_to_the_view() -> void:
	var a := _animator()
	for i: int in 10:  # a hold lasts a while (the blend into it is over)
		a.apply(_v(Fighter.State.HOLDING), 0.016)
	a.apply(_v(Fighter.State.IDLE, true, 0, 6), 0.016)  # the sim drops straight to idle, frozen
	assert_eq(a.current_anim(), AnimMap.Anim.THROW, "the toss shows")
	assert_eq(a.seek_clip(), "Throw")
	assert_almost_eq(a.play_position(), float(SwingClips.THROW["contact"]), 0.001, "release pose through hitstop")
	for i: int in 30:
		a.apply(_v(Fighter.State.IDLE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.IDLE, "back to the view after the follow-through")


func test_the_throw_event_plays_the_toss_even_if_the_frozen_frame_was_skipped() -> void:
	var a := _animator()
	for i: int in 10:
		a.apply(_v(Fighter.State.HOLDING), 0.016)
	a.toss()  # the sim's throw hit, seen this frame
	a.apply(_v(Fighter.State.MOVE), 0.016)  # the render caught up past the hitstop
	assert_eq(a.current_anim(), AnimMap.Anim.THROW)


func test_a_toss_request_is_dropped_if_the_fighter_is_busy() -> void:
	var a := _animator()
	a.toss()
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	a.apply(_v(Fighter.State.IDLE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.IDLE, "a stale toss never plays later")


func test_each_hit_replays_the_flinch_and_heavy_hits_rock_harder() -> void:
	var a := _animator()
	for i: int in 20:
		a.apply(_v(Fighter.State.HITSTUN), 0.016)
	var late := a.play_position()
	a.flinch(false)
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	assert_lt(a.play_position(), late, "the next combo hit flinches again from the start")
	assert_eq(a.clip_for(AnimMap.Anim.HIT), "Hit_A", "a light hit: a quick flinch")
	a.flinch(true)
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	assert_eq(a.clip_for(AnimMap.Anim.HIT), "Hit_B", "a heavy hit rocks the body back")


func test_a_flinch_request_is_dropped_when_not_in_hitstun() -> void:
	var a := _animator()
	a.flinch(true)
	a.apply(_v(Fighter.State.GUARD), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.GUARD)
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	assert_eq(a.clip_for(AnimMap.Anim.HIT), "Hit_A", "the guarded frame used the cue up")


func test_letting_go_without_a_throw_just_stands() -> void:
	var a := _animator()
	a.apply(_v(Fighter.State.HOLDING), 0.016)
	a.apply(_v(Fighter.State.IDLE), 0.016)
	assert_eq(a.current_anim(), AnimMap.Anim.IDLE, "a timed-out hold has no hitstop: no toss")


func test_the_first_hit_blends_in_once_and_does_not_restart_next_frame() -> void:
	var a := _animator()
	for i: int in 5:
		a.apply(_v(Fighter.State.IDLE), 0.016)
	a.flinch(true)
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	assert_eq(a.clip_for(AnimMap.Anim.HIT), "Hit_B", "the first heavy hit already rocks back")
	for i: int in 5:
		a.apply(_v(Fighter.State.HITSTUN), 0.016)
	var pos := a.play_position()
	a.apply(_v(Fighter.State.HITSTUN), 0.016)
	assert_gt(a.play_position(), pos, "no stale restart")
