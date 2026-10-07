extends GutTest
## Projectile visuals (combat-motion B1): one view per sim projectile id, interpolated like items.


func _proj(id: int, kind: int, pos: Vector3, owner: int = 0) -> Dictionary:
	return {"id": id, "owner": owner, "kind": kind, "pos": pos, "vel": Vector3(10, 0, 0), "radius": 0.3,
			"ticks_left": 20}


func _layer() -> ProjectileLayer:
	var layer := ProjectileLayer.new()
	add_child_autofree(layer)
	return layer


func test_one_view_per_id_and_freed_when_gone() -> void:
	var layer := _layer()
	var a := _proj(0, Projectile.Kind.BOLT, Vector3.ZERO)
	var b := _proj(1, Projectile.Kind.FIREBALL, Vector3(2, 1, 0))
	layer.sync([], [a, b], 1.0)
	assert_eq(layer.view_count(), 2)
	var bolt := layer.view(0)
	layer.sync([a, b], [a, b], 1.0)
	assert_eq(layer.view(0), bolt, "the same id keeps its view")
	layer.sync([a, b], [b], 1.0)
	assert_eq(layer.view_count(), 1, "a projectile that hit or expired loses its view")
	assert_null(layer.view(0))
	assert_eq(layer.view(1).kind(), Projectile.Kind.FIREBALL)


func test_interpolates_between_ticks() -> void:
	var layer := _layer()
	var before := _proj(0, Projectile.Kind.BOLT, Vector3(0, 1, 0))
	var after := _proj(0, Projectile.Kind.BOLT, Vector3(2, 1, 0))
	layer.sync([before], [after], 0.25)
	assert_almost_eq(layer.view(0).position.x, 0.5, 0.0001)
	layer.sync([before], [after], 1.0)
	assert_almost_eq(layer.view(0).position.x, 2.0, 0.0001)


func test_a_new_id_starts_where_it_is() -> void:
	var layer := _layer()
	layer.sync([], [_proj(3, Projectile.Kind.BOLT, Vector3(4, 1, 0))], 0.0)
	assert_almost_eq(layer.view(3).position.x, 4.0, 0.0001, "no slide in from the origin")


func test_clear_frees_every_view() -> void:
	var layer := _layer()
	layer.sync([], [_proj(0, Projectile.Kind.BOLT, Vector3.ZERO), _proj(1, Projectile.Kind.HEAVY_BOLT, Vector3.ZERO)], 1.0)
	layer.clear()
	assert_eq(layer.view_count(), 0)


func test_bigger_kinds_look_bigger() -> void:
	var c := GameConfig.new()
	var bolt := ProjectileLook.visual_radius(Projectile.Kind.BOLT, c.bolt_radius)
	var heavy := ProjectileLook.visual_radius(Projectile.Kind.HEAVY_BOLT, c.heavy_bolt_radius)
	var fire := ProjectileLook.visual_radius(Projectile.Kind.FIREBALL, c.fireball_radius)
	assert_gt(heavy, bolt)
	assert_gt(fire, heavy)
	assert_gt(bolt, 0.1, "a bolt is still big enough to see from the match camera")


func test_the_trail_streams_behind_a_moving_projectile() -> void:
	var layer := _layer()
	var prev := _proj(0, Projectile.Kind.BOLT, Vector3(0, 1, 0))
	for i: int in 8:
		var curr := _proj(0, Projectile.Kind.BOLT, Vector3(0.3 * (i + 1), 1, 0))
		layer.sync([prev], [curr], 1.0)
		layer.view(0).advance(1.0 / 60.0)
		prev = curr
	var v := layer.view(0)
	assert_gt(v.trail_length(), 0.5, "the trail reaches back along the flight")
	assert_lt(v.trail_tail().x, v.position.x, "the trail lies behind the head")


func test_the_fireball_flickers() -> void:
	var layer := _layer()
	var p := _proj(0, Projectile.Kind.FIREBALL, Vector3(0, 1, 0))
	layer.sync([p], [p], 1.0)
	var v := layer.view(0)
	var seen := {}
	for i: int in 20:
		v.advance(1.0 / 60.0)
		seen[snappedf(v.core_scale(), 0.01)] = true
	assert_gt(seen.size(), 3, "the flame core keeps changing size")


func test_a_reused_id_of_another_kind_gets_a_fresh_view() -> void:
	var layer := _layer()
	layer.sync([], [_proj(0, Projectile.Kind.BOLT, Vector3.ZERO)], 1.0)
	layer.sync([], [_proj(0, Projectile.Kind.FIREBALL, Vector3.ZERO)], 1.0)
	assert_eq(layer.view(0).kind(), Projectile.Kind.FIREBALL, "a restarted run never shows the old look")
