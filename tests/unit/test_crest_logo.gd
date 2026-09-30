extends GutTest
## CrestLogo (design.md DS-CMP-15): the shield crest with crossed bat and shaft and the bomb,
## drawn in code from DS tokens; idle spark flicker; registered in the gallery.

const CREST := preload("res://src/ui/components/crest_logo/crest_logo.tscn")


func _crest() -> CrestLogo:
	var c := CREST.instantiate() as CrestLogo
	add_child_autofree(c)
	return c


func test_default_size_reads_as_a_logo() -> void:
	var c := _crest()
	assert_eq(c.custom_minimum_size, Vector2.ONE * CrestLogo.DEFAULT_SIZE)
	assert_eq(CrestLogo.DEFAULT_SIZE, float(DS.S8 * 2), "about twice the old leaf emblem")


func test_shield_is_a_closed_pointed_outline() -> void:
	var pts := CrestLogo.shield_points(1.0)
	assert_gt(pts.size(), 8)
	var lowest := pts[0]
	for p: Vector2 in pts:
		if p.y > lowest.y:
			lowest = p
	assert_almost_eq(lowest.x, 0.0, 0.01, "the shield ends in a point at the bottom center")
	var inner := CrestLogo.shield_points(CrestLogo.INNER_SCALE)
	assert_lt(inner[0].length(), pts[0].length(), "inner shield sits inside")


func test_star_has_alternating_points() -> void:
	var star := CrestLogo.star_points(Vector2.ZERO, 1.0, CrestLogo.SPARK_POINTS)
	assert_eq(star.size(), CrestLogo.SPARK_POINTS * 2)
	assert_almost_eq(star[0].length(), 1.0, 0.001)
	assert_lt(star[1].length(), 1.0)


func test_idle_spark_flickers_only_when_animated() -> void:
	var c := _crest()
	assert_eq(c.state(), CrestLogo.State.IDLE)
	await wait_seconds(UiMotion.duration(UiMotion.Token.BASE) * 0.5)
	assert_eq(c.spark_scale, 1.0, "still")
	c.set_state(CrestLogo.State.ANIMATED)
	await wait_seconds(UiMotion.duration(UiMotion.Token.BASE) * 0.5)
	assert_ne(c.spark_scale, 1.0, "the spark flickers")
	c.set_state(CrestLogo.State.IDLE)
	assert_eq(c.spark_scale, 1.0)


func test_gallery_registers_the_crest() -> void:
	var registered: Array[String] = []
	for entry: Array in (load("res://src/debug/ds_gallery.gd") as GDScript).get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	assert_true(registered.has("res://src/ui/components/crest_logo/crest_logo.tscn"))


func test_login_card_shows_the_crest() -> void:
	var p := (load("res://src/ui/components/login_panel/login_panel.tscn") as PackedScene).instantiate() as LoginPanel
	add_child_autofree(p)
	assert_not_null(p.crest(), "the crest sits above the title")
	assert_eq(p.crest().state(), CrestLogo.State.ANIMATED)
