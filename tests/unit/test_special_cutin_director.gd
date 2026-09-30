extends GutTest
## Special cut-in director (Phase 5 T4, GD-CAM-01): focuses the match camera on the caster, pans
## (never snaps) to a second caster, ends early on a KO, re-reads reduce motion on restart and
## leaves the sim exactly as it would be without it.

const DT := 1.0 / 60.0


func _start_event(slot: int, special: String = SpecialCatalog.GROUND_SLAM) -> Dictionary:
	return {"type": "special_start", "fighter": slot, "character": "barbarian", "special": special,
		"pos": Vector3.ZERO}


func _director(reduce: bool = false) -> Array:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(GameConfig.new())
	var director := SpecialCutInDirector.new()
	add_child_autofree(director)
	director.setup(rig, reduce)
	return [director, rig]


func _xc_world() -> World:
	var chars: Array[String] = ["barbarian", "mage"]
	var w := World.new(GameConfig.new(), 3, 2, null, chars)
	w.fighters[0].gauge = SpecialGauge.MAX
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.5, 0, 0)
	return w


func _xc_inputs(tick: int) -> Array[InputFrame]:
	var press := tick == 5
	return [InputFrame.make(0, 0, false, false, press, press), InputFrame.neutral()]


func test_director_focuses_the_camera_on_the_caster() -> void:
	var pair := _director()
	var director: SpecialCutInDirector = pair[0]
	var rig: CameraRig = pair[1]
	var chars: Array[String] = ["barbarian", "mage"]
	var view := World.new(GameConfig.new(), 3, 2, null, chars).state_view()
	director.present(view, [_start_event(1)], DT)
	for i: int in 20:
		director.present(view, [], DT)
	assert_gt(rig.focus_weight(), 0.9)
	var caster: Vector3 = view["fighters"][1]["pos"]
	assert_almost_eq(rig.focus_point().x, caster.x, 0.001)
	director.reset()
	assert_eq(rig.focus_weight(), 0.0, "a restart drops the cut-in")


func test_a_match_with_the_cut_in_plays_the_same_sim_as_one_without() -> void:
	var director: SpecialCutInDirector = _director()[0]
	var shown := _xc_world()
	var plain := _xc_world()
	var started := false
	for t: int in 120:
		shown.tick(_xc_inputs(t))
		var view := shown.state_view()
		director.present(view, view["events"], DT)
		started = started or director.cut_in().is_active()
		plain.tick(_xc_inputs(t))
	assert_true(started, "the special fired and the cut-in ran")
	assert_eq(shown.state_hash(), plain.state_hash(), "render-only: identical sim with and without the cut-in")


func test_a_knocked_out_caster_ends_the_cut_in_early() -> void:
	var pair := _director()
	var director: SpecialCutInDirector = pair[0]
	var view := {"fighters": [{"id": 0, "pos": Vector3.ZERO, "state": Fighter.State.SPECIAL}]}
	director.present(view, [_start_event(0)], DT)
	for i: int in 15:
		director.present(view, [], DT)
	assert_almost_eq(director.cut_in().weight(), 1.0, 0.001, "holding")
	var ko := {"fighters": [{"id": 0, "pos": Vector3(0, -20, 0), "state": Fighter.State.KO}]}
	var frames := 0
	while director.cut_in().is_active() and frames < 200:
		director.present(ko, [], DT)
		frames += 1
	assert_lt(frames, roundi((SpecialCutIn.OUT_S + SpecialCutIn.HOLD_S * 0.5) / DT), "eases out without the hold")
	assert_almost_eq((pair[1] as CameraRig).focus_point().y, 0.0, 0.001, "keeps the last live position")


func test_reduce_motion_is_read_again_on_restart() -> void:
	var director: SpecialCutInDirector = _director(false)[0]
	director.reset(true)
	assert_true(director.cut_in().is_reduced())
	director.reset(false)
	assert_false(director.cut_in().is_reduced())


func test_a_second_caster_pans_the_focus_instead_of_snapping() -> void:
	var pair := _director()
	var director: SpecialCutInDirector = pair[0]
	var rig: CameraRig = pair[1]
	var view := {"fighters": [{"id": 0, "pos": Vector3.ZERO, "state": Fighter.State.SPECIAL},
		{"id": 1, "pos": Vector3(10, 0, 0), "state": Fighter.State.SPECIAL}]}
	director.present(view, [_start_event(0)], DT)
	assert_eq(rig.focus_point(), Vector3.ZERO, "the first caster is taken at once (the zoom starts from 0)")
	for i: int in 15:
		director.present(view, [], DT)
	director.present(view, [_start_event(1)], DT)
	assert_lt(rig.focus_point().x, 3.0, "no jump to the new caster")
	for i: int in 30:
		director.present(view, [], DT)
	assert_almost_eq(rig.focus_point().x, 10.0, 0.3, "settles on the new caster")
