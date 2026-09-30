class_name LogBridgeView
extends ArenaDressing
## Log bridge (PRD-ARENA-02): the bridge spans a wide river (WaterView draws the ring-out water)
## between two grassy banks past the bridge ends, where the trees stand. Short posts mark the
## bridge ends; lily pads and river stones dot the water away from the deck.

const BANK_X := 16.0
const BANK_LENGTH := 40.0
const BANK_DEPTH := 90.0
const BANK_TOP := -0.2
const BANK_HEIGHT := 1.2
const BANK_TREES := 5
const POST_RADIUS := 0.16
const POST_HEIGHT := 1.1
const POST_OUTSET := 0.3
const PAD_COUNT := 12
const PAD_RADIUS := 0.55
const PAD_MIN_Z := 3.2
const STONE_COUNT := 6
const STONE_RADIUS := 0.7


func prop_ground(p: Vector3) -> float:
	return BANK_TOP if absf(p.x) >= BANK_X + ZONE_MARGIN else NAN


func inner_flowers() -> bool:
	return false


func _build() -> void:
	var water_y := _water_line()
	for side: float in [-1.0, 1.0]:
		_bank(side)
	_posts(water_y)
	_river_bits(water_y)


func _water_line() -> float:
	for z: ArenaShape in _arena.ringout_zones:
		return z.center.y
	return DecorView.GROUND_Y


func _bank(side: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(BANK_LENGTH, BANK_HEIGHT, BANK_DEPTH)
	var x := side * (BANK_X + BANK_LENGTH * 0.5)
	_piece(box, _theme.outer_ground, Vector3(x, BANK_TOP - BANK_HEIGHT * 0.5, 0))
	var edge := BoxMesh.new()
	edge.size = Vector3(0.6, BANK_HEIGHT * 0.9, BANK_DEPTH)
	_piece(edge, _theme.rim, Vector3(side * (BANK_X + 0.2), BANK_TOP - BANK_HEIGHT * 0.5, 0))
	for i: int in BANK_TREES:
		var tree := SphereCluster.new()
		var size := _rng.randf_range(1.3, 1.9)
		tree.setup(_theme.canopy, size, _rng.randi(), TREE_TRUNK)
		tree.position = Vector3(side * (BANK_X + _rng.randf_range(3.0, 9.0)), BANK_TOP, _rng.randf_range(-14.0, 6.0))
		add_child(tree)
		add_occluder(tree, size, size * PROP_HEIGHT_PER_SIZE + TREE_TRUNK * size)


func _posts(water_y: float) -> void:
	var post := CylinderMesh.new()
	post.top_radius = POST_RADIUS
	post.bottom_radius = POST_RADIUS * 1.15
	post.height = POST_HEIGHT
	var half := _arena.item_area.half if _arena.item_area != null else Vector2(12, 2)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * (half.x + POST_OUTSET), water_y + POST_HEIGHT * 0.5, sz * (half.y + POST_OUTSET))
			add_occluder(_piece(post, _theme.rim, p), POST_RADIUS, POST_HEIGHT)


func _river_bits(water_y: float) -> void:
	var pad := CylinderMesh.new()
	pad.top_radius = PAD_RADIUS
	pad.bottom_radius = PAD_RADIUS
	pad.height = 0.04
	for i: int in PAD_COUNT:
		var z := _rng.randf_range(PAD_MIN_Z, 11.0) * (1.0 if i % 2 == 0 else -1.0)
		_piece(pad, DS.GRASS_MID, Vector3(_rng.randf_range(-13.0, 13.0), water_y + 0.03, z))
	var stone := SphereMesh.new()
	stone.radius = STONE_RADIUS
	stone.height = STONE_RADIUS * 0.7
	for i: int in STONE_COUNT:
		var z := _rng.randf_range(6.0, 12.0) * (1.0 if i % 2 == 1 else -1.0)
		var rock := _piece(stone, DS.STONE_SHADE, Vector3(_rng.randf_range(-12.0, 12.0), water_y, z))
		rock.scale = Vector3(1.0, 1.0, _rng.randf_range(0.6, 1.0))
