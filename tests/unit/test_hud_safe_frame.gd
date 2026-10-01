extends GutTest
## HudSafeFrame through the real CameraRig (combat-depth D): with a share of the screen reserved
## for the HUD strip, the targets fill exactly the free band — the near extent sits on the strip's
## edge and the far extent on the opposite screen edge, centred in the band, not pushed past it.


func _rig(top: float, bottom: float) -> CameraRig:
	var c := GameConfig.new()
	c.cam_margin = 0.0
	c.cam_zoom_min = 1.0
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(c)
	rig.set_hud_reserve(top, bottom)
	return rig


func _shares(rig: CameraRig) -> Array[float]:
	var targets := PackedVector3Array([Vector3(0, 0, -6), Vector3(0, 0, 6)])
	for i: int in 5:
		rig.follow(targets, 10.0)
	var h := rig.get_viewport().get_visible_rect().size.y
	return [rig.unproject(targets[0]).y / h, rig.unproject(targets[1]).y / h]


func test_no_reserve_fills_the_screen() -> void:
	var s := _shares(_rig(0.0, 0.0))
	assert_almost_eq(s[0], 0.0, 0.02, "far edge at the top")
	assert_almost_eq(s[1], 1.0, 0.02, "near edge at the bottom")


func test_bottom_strip_band() -> void:
	var s := _shares(_rig(0.0, 0.2))
	assert_almost_eq(s[0], 0.0, 0.02)
	assert_almost_eq(s[1], 0.8, 0.02, "near edge on the strip's top edge")


func test_top_strip_band() -> void:
	var s := _shares(_rig(0.2, 0.0))
	assert_almost_eq(s[0], 0.2, 0.02, "far edge under the strip")
	assert_almost_eq(s[1], 1.0, 0.02)
