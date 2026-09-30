extends GutTest
## ChargeGauge (design.md DS-CMP-05): petal yellow -> campfire orange, glow when full.

const SCENE := preload("res://src/ui/components/charge_gauge/charge_gauge.tscn")


func _gauge() -> ChargeGauge:
	var g := SCENE.instantiate() as ChargeGauge
	add_child_autofree(g)
	return g


func test_value_is_clamped() -> void:
	var g := _gauge()
	g.set_value(1.4)
	assert_eq(g.value(), 1.0)
	assert_true(g.is_full())
	g.set_value(-0.2)
	assert_eq(g.value(), 0.0)


func test_color_ramp() -> void:
	var g := _gauge()
	g.set_value(0.0)
	assert_eq(g.fill_color(), DS.PETAL_YELLOW)
	g.set_value(0.5)
	assert_eq(g.fill_color(), DS.PETAL_YELLOW.lerp(DS.FIRE, 0.5))
	g.set_value(1.0)
	assert_eq(g.fill_color(), DS.GLOW, "full charge glows")


func test_layer_shows_a_gauge_only_while_charging() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].set_state(Fighter.State.CHARGE)
	w.fighters[0].charge_ticks = SimTime.to_ticks(c.heavy_charge_max_time) / 2
	var layer := ChargeGaugeLayer.new()
	add_child_autofree(layer)
	var project := func(p: Vector3) -> Vector2: return Vector2(p.x * 10.0 + 500.0, p.z * 10.0 + 300.0)
	layer.update_from(w.state_view(), c, project)
	var g0 := layer.gauge(0)
	assert_true(g0.visible)
	assert_almost_eq(g0.value(), 0.5, 0.001)
	var expected: Vector2 = project.call(w.fighters[0].pos + Vector3.UP * (c.fighter_height + ChargeGaugeLayer.HEAD_GAP))
	assert_almost_eq(g0.position + g0.size * 0.5, expected, Vector2(0.01, 0.01))
	assert_false(layer.gauge(1).visible, "idle fighter has no gauge")
	w.fighters[0].set_state(Fighter.State.IDLE)
	layer.update_from(w.state_view(), c, project)
	assert_false(g0.visible)


func test_layer_hides_gauges_the_camera_cannot_see() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].set_state(Fighter.State.CHARGE)
	var layer := ChargeGaugeLayer.new()
	add_child_autofree(layer)
	var project := func(p: Vector3) -> Vector2: return Vector2(p.x, p.z)
	layer.update_from(w.state_view(), c, project, func(_p: Vector3) -> bool: return false)
	assert_false(layer.gauge(0).visible, "behind the camera or off screen (special cut-in close shot)")
	layer.update_from(w.state_view(), c, project, func(_p: Vector3) -> bool: return true)
	assert_true(layer.gauge(0).visible)
