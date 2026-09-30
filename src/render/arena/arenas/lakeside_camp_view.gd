class_name LakesideCampView
extends ArenaDressing
## Lakeside camp (PRD-ARENA-01): reeds and pebbles along the far lake shore and a camp tent in the
## meadow behind the campfire side, all outside the ring. The lake itself is WaterView (ring-out
## zone) and the campfire is CampfireView.

const REED_COUNT := 14
const REED_RADIUS := 0.06
const REED_HEIGHT := 1.1
const PEBBLE_COUNT := 8
const PEBBLE_RADIUS := 0.35
## Only shore stretches this far outside the arena floor get reeds and pebbles.
const SHORE_CLEARANCE := 1.2
const TENT_SIZE := Vector3(2.4, 1.8, 2.8)
const TENT_ANGLE_DEG := 215.0
const TENT_OFFSET := 5.0


func _build() -> void:
	var lake := _lake()
	if lake != null:
		_shore(lake)
	_tent()


func _lake() -> ArenaShape:
	for z: ArenaShape in _arena.ringout_zones:
		if z.tag == "lake":
			return z
	return null


func _shore(lake: ArenaShape) -> void:
	var reed := CylinderMesh.new()
	reed.top_radius = REED_RADIUS * 0.4
	reed.bottom_radius = REED_RADIUS
	reed.height = REED_HEIGHT
	var pebble := SphereMesh.new()
	pebble.radius = PEBBLE_RADIUS
	pebble.height = PEBBLE_RADIUS
	var floor_r := _arena.view_radius()
	for i: int in REED_COUNT + PEBBLE_COUNT:
		var a := _rng.randf() * TAU
		var p := lake.center + Vector3(cos(a), 0, sin(a)) * (lake.radius + _rng.randf_range(-0.2, 0.4))
		if Vector2(p.x, p.z).length() < floor_r + SHORE_CLEARANCE:
			continue
		var is_reed := i < REED_COUNT
		var y := lake.center.y + (REED_HEIGHT * 0.5 if is_reed else 0.0)
		_piece(reed if is_reed else pebble, _theme.bush if is_reed else DS.STONE_CREAM, Vector3(p.x, y, p.z))


func _tent() -> void:
	var a := deg_to_rad(TENT_ANGLE_DEG)
	var at := Vector3(cos(a), 0, sin(a)) * (_arena.view_radius() + TENT_OFFSET)
	var prism := PrismMesh.new()
	prism.size = TENT_SIZE
	var tent := _piece(prism, DS.PETAL_BLUE, Vector3(at.x, DecorView.GROUND_Y + TENT_SIZE.y * 0.5, at.z), 0.2)
	tent.rotation.y = -a
	var flap := PrismMesh.new()
	flap.size = TENT_SIZE * Vector3(0.45, 0.7, 1.02)
	var door := _piece(flap, DS.CANOPY_DEEP, tent.position + Vector3(0, -TENT_SIZE.y * 0.15, 0))
	door.rotation.y = -a
	add_occluder(tent, TENT_SIZE.z * 0.5, TENT_SIZE.y)
