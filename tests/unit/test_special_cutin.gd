extends GutTest
## Special-move cut-in (Phase 5 T4, design.md GD-CAM-01): render-only timing on motion tokens, a
## close shot blended over the match framing, reduce motion keeps the camera still, and the
## director never touches the sim.

const DT := 1.0 / 60.0


func _start_event(slot: int, special: String = SpecialCatalog.GROUND_SLAM) -> Dictionary:
	return {"type": "special_start", "fighter": slot, "character": "barbarian", "special": special,
		"pos": Vector3.ZERO}


func _run(cut: SpecialCutIn, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		cut.update(DT)
		t += DT


func test_idle_until_a_special_starts() -> void:
	var cut := SpecialCutIn.new()
	cut.on_events([{"type": "hit", "attacker": 0, "target": 1}])
	assert_false(cut.is_active())
	assert_eq(cut.weight(), 0.0)
	assert_eq(cut.slot(), -1)


func test_zooms_in_holds_and_returns_on_motion_tokens() -> void:
	var cut := SpecialCutIn.new()
	cut.on_events([_start_event(1)])
	assert_true(cut.is_active())
	assert_eq(cut.slot(), 1)
	assert_eq(cut.special(), SpecialCatalog.GROUND_SLAM)
	_run(cut, SpecialCutIn.IN_S)
	assert_almost_eq(cut.weight(), 1.0, 0.001, "fully zoomed after motion_base")
	_run(cut, SpecialCutIn.HOLD_S)
	assert_almost_eq(cut.weight(), 1.0, 0.05, "held for motion_calm")
	_run(cut, SpecialCutIn.OUT_S * 0.5)
	assert_between(cut.weight(), 0.05, 0.95, "easing back")
	_run(cut, SpecialCutIn.OUT_S * 0.5 + DT)
	assert_false(cut.is_active())
	assert_eq(cut.weight(), 0.0)
	assert_almost_eq(SpecialCutIn.total_seconds(), DS.MOTION_BASE + DS.MOTION_CALM + DS.MOTION_SLOW, 0.0001,
			"timings are DS motion tokens")


func test_weight_rises_then_falls_without_jumps() -> void:
	var cut := SpecialCutIn.new()
	cut.on_events([_start_event(0)])
	var last := 0.0
	var steps := int(ceil(SpecialCutIn.total_seconds() / DT)) + 2
	for i: int in steps:
		cut.update(DT)
		assert_lt(absf(cut.weight() - last), 0.2, "no pop at step %d" % i)
		last = cut.weight()


func test_a_second_special_retargets_without_dropping_the_zoom() -> void:
	var cut := SpecialCutIn.new()
	cut.on_events([_start_event(0)])
	_run(cut, SpecialCutIn.IN_S + SpecialCutIn.HOLD_S + SpecialCutIn.OUT_S * 0.5)
	var before := cut.weight()
	cut.on_events([_start_event(2, SpecialCatalog.BIG_FIREBALL)])
	assert_eq(cut.slot(), 2)
	assert_eq(cut.special(), SpecialCatalog.BIG_FIREBALL)
	assert_almost_eq(cut.weight(), before, 0.02, "continues from the current zoom")
	_run(cut, SpecialCutIn.IN_S)
	assert_almost_eq(cut.weight(), 1.0, 0.001, "then zooms fully onto the new caster")


func test_cancel_eases_out_from_where_it_is() -> void:
	var cut := SpecialCutIn.new()
	cut.on_events([_start_event(0)])
	_run(cut, SpecialCutIn.IN_S + DT)
	cut.cancel()
	assert_almost_eq(cut.weight(), 1.0, 0.02)
	_run(cut, SpecialCutIn.OUT_S + DT)
	assert_false(cut.is_active())


func test_reduce_motion_keeps_the_camera_still() -> void:
	var cut := SpecialCutIn.new(true)
	cut.on_events([_start_event(0)])
	_run(cut, SpecialCutIn.IN_S)
	assert_gt(cut.weight(), 0.9, "the banner still shows")
	assert_eq(cut.camera_weight(), 0.0, "no zoom with reduce motion")
	assert_eq(SpecialCutIn.new().camera_weight(), 0.0)


func test_shot_blends_from_the_match_framing_to_a_close_low_shot() -> void:
	var focus := Vector3(4, 0, -2)
	var none := SpecialCutIn.shot(Vector3.ZERO, 40.0, 60.0, focus, 0.0)
	assert_eq(none["center"], Vector3.ZERO)
	assert_eq(none["distance"], 40.0)
	assert_eq(none["pitch"], 60.0)
	var full := SpecialCutIn.shot(Vector3.ZERO, 40.0, 60.0, focus, 1.0)
	assert_eq(full["center"], focus + Vector3.UP * SpecialCutIn.FOCUS_HEIGHT)
	assert_eq(full["distance"], SpecialCutIn.ZOOM_DISTANCE)
	assert_eq(full["pitch"], SpecialCutIn.PITCH_DEG)
	var near := SpecialCutIn.shot(Vector3.ZERO, 4.0, 60.0, focus, 1.0)
	assert_eq(near["distance"], 4.0, "never pulls back from an already closer camera")


func test_banner_names_the_special_in_the_caster_color() -> void:
	var banner := SpecialCutInBanner.new()
	add_child_autofree(banner)
	banner.show_cut(1, SpecialCatalog.SPIN_SLASH, 1.0, false)
	assert_true(banner.is_showing())
	assert_eq(banner.title(), "P2 · 회전 베기")
	var band := banner.band_color()
	assert_eq(Color(band, 1.0), PlayerStyle.color(1), "P2 color")
	banner.show_cut(-1, "", 0.0, false)
	assert_false(banner.is_showing())
	for id: String in SpecialCatalog.IDS:
		assert_true(SpecialCutInBanner.NAMES.has(id), "%s has a display name" % id)


func test_director_focuses_the_camera_on_the_caster_and_leaves_the_sim_alone() -> void:
	var config := GameConfig.new()
	var chars: Array[String] = ["barbarian", "mage"]
	var world := World.new(config, 3, 2, null, chars)
	var hash_before := world.state_hash()
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(config)
	var director := SpecialCutInDirector.new()
	add_child_autofree(director)
	director.setup(rig, false)
	var view := world.state_view()
	director.present(view, [_start_event(1)], DT)
	for i: int in 20:
		director.present(view, [], DT)
	assert_gt(rig.focus_weight(), 0.9)
	var caster: Vector3 = view["fighters"][1]["pos"]
	assert_almost_eq(rig.focus_point().x, caster.x, 0.001)
	assert_eq(world.state_hash(), hash_before, "render-only: the sim is untouched")
	director.reset()
	assert_eq(rig.focus_weight(), 0.0, "a restart drops the cut-in")
