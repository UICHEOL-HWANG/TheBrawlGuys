class_name DecorView
extends Node3D
## Meadow around the arena (design.md DS-VIS-04, PRD §6.1): the outer ground, the arena's own set
## dressing (ArenaDressing), a rock and bushes / trees / arena props scattered on a ring outside
## the floor where the dressing allows them, and flower patches (floor decals, may lie inside).
## Tall pieces never stand between the match camera and the arena core: DecorOcclusion drops
## any scattered prop that would. Re-lays out when a follow_config arena's radius changes.

const GROUND_Y := -1.0
const GROUND_SIZE := 400.0
const PROP_COUNT := 14
const FLOWER_COUNT := 24
const LAKE_RADIUS := 12.0
const LAKE_OFFSET := 14.0
const LAKE_SEGMENTS := 48
const LAKE_LIFT := 0.05
const ROCK_SCALE := Vector3(1.6, 1.1, 1.3)
const ROCK_ANGLE := PI * 0.75
const ROCK_OFFSET := 4.0
const ROCK_LIFT := 0.6
const PROP_OFFSET := Vector2(2.5, 6.0)
const FLOWER_COLORS := [DS.PETAL_PINK, DS.PETAL_BLUE, DS.PETAL_YELLOW]
## Ring-out zone tags that are water (splash VFX / SFX).
const WATER_ZONES: Array[String] = ["lake", "water"]

var _config: GameConfig
var _arena: ArenaData
var _dressing: ArenaDressing
## {node, angle, "offset" (outside the ring) or "frac" (inside), and either "y" (fixed height) or
## "lift" (above the dressing's ground); tall pieces also carry radius, height and "drop" (the
## node origin's height above the piece's base)}
var _items: Array[Dictionary] = []


## arena: the arena to dress (default: the classic circle); theme: its look (default: its theme).
func setup(config: GameConfig, p_seed: int, arena: ArenaData = null, theme: ArenaTheme = null) -> void:
	_config = config
	_arena = arena if arena != null else ArenaCatalog.default(config)
	var look := theme if theme != null else ArenaTheme.for_id(_arena.theme_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	_dressing = ArenaDressings.create(_arena.id)
	add_child(_dressing)
	_dressing.setup(_arena, look, config, rng.randi())
	_add_ground(look)
	if _dressing.has_decor_lake():
		_add_lake(look)
	_add_rock()
	_add_props(rng)
	_add_flowers(rng)
	if _arena.follow_config:
		_config.changed.connect(_layout)
	_layout()


## Every shown decor piece that could hide the fight: {pos, radius, height}.
func occluders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in _items:
		var node: Node3D = item["node"]
		if item.has("radius") and node.visible:
			out.append({"pos": _base(node, item), "radius": item["radius"], "height": item["height"]})
	for o: Dictionary in _dressing.occluders():
		out.append({"pos": _base(o["node"], o), "radius": o["radius"], "height": o["height"]})
	return out


func dressing() -> ArenaDressing:
	return _dressing


func _layout() -> void:
	if _arena.follow_config:
		_arena.sync(_config)
	var poses := DecorOcclusion.match_poses(_config, _arena)
	var bound := _arena.view_radius()
	for item: Dictionary in _items:
		var node: Node3D = item["node"]
		var angle: float = item["angle"]
		var dist: float = bound * float(item["frac"]) if item.has("frac") else bound + float(item["offset"])
		var p := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var y := _height_at(item, p)
		node.visible = not is_nan(y)
		if not node.visible:
			continue
		node.position = Vector3(p.x, y, p.z)
		if item.has("radius"):
			node.visible = not DecorOcclusion.blocks_any(poses, _base(node, item), item["radius"], item["height"])


## Bottom of a tall piece: its node origin lowered by the piece's drop.
static func _base(node: Node3D, piece: Dictionary) -> Vector3:
	return node.position - Vector3(0.0, float(piece.get("drop", 0.0)), 0.0)


## Fixed height, the arena floor (inside the ring) or the dressing's ground plus lift (NAN = none).
func _height_at(item: Dictionary, p: Vector3) -> float:
	if item.has("y"):
		return float(item["y"])
	if item.has("frac"):
		return 0.0
	return _dressing.prop_ground(p) + float(item.get("lift", 0.0))


func _add_props(rng: RandomNumberGenerator) -> void:
	for i: int in PROP_COUNT:
		var made := _dressing.make_prop(rng, i)
		var node: Node3D = made["node"]
		add_child(node)
		_items.append({"node": node, "angle": TAU * i / PROP_COUNT + rng.randf_range(-0.15, 0.15),
			"offset": rng.randf_range(PROP_OFFSET.x, PROP_OFFSET.y), "radius": made["radius"], "height": made["height"]})


func _add_flowers(rng: RandomNumberGenerator) -> void:
	for i: int in FLOWER_COUNT:
		var inside := i % 2 == 0
		if inside and not _dressing.inner_flowers():
			continue
		var patch := FlowerPatch.new()
		add_child(patch)
		patch.setup(FLOWER_COLORS[i % FLOWER_COLORS.size()], rng.randi())
		var item := {"node": patch, "angle": rng.randf_range(0.0, TAU)}
		if inside:
			item["frac"] = rng.randf_range(0.15, 0.85)
		else:
			item["offset"] = rng.randf_range(1.0, 8.0)
		_items.append(item)


func _add_ground(theme: ArenaTheme) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane
	mi.material_override = ToonMaterials.toon(theme.outer_ground)
	mi.position.y = GROUND_Y
	add_child(mi)


func _add_lake(theme: ArenaTheme) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS
	disc.bottom_radius = LAKE_RADIUS
	disc.height = 0.1
	disc.radial_segments = LAKE_SEGMENTS
	mi.mesh = disc
	mi.material_override = ToonMaterials.toon(theme.water)
	add_child(mi)
	_items.append({"node": mi, "angle": 0.0, "offset": LAKE_OFFSET, "y": GROUND_Y + LAKE_LIFT})


func _add_rock() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.scale = ROCK_SCALE
	mi.material_override = ToonMaterials.toon(DS.STONE_CREAM)
	add_child(mi)
	_items.append({"node": mi, "angle": ROCK_ANGLE, "offset": ROCK_OFFSET, "lift": ROCK_LIFT,
		"radius": ROCK_SCALE.x * 0.5, "height": ROCK_SCALE.y, "drop": ROCK_SCALE.y * 0.5})


## True when a point is horizontally over the classic meadow lake (grown by margin).
static func is_over_lake(pos: Vector3, arena_radius: float, margin: float = 0.0) -> bool:
	return Vector2(pos.x - (arena_radius + LAKE_OFFSET), pos.z).length() <= LAKE_RADIUS + margin


## A ring-out that ends in water splashes (DS-VFX-05): a water zone, or over the meadow lake
## when the arena has one (decor_lake: ArenaDressings.has_decor_lake).
static func is_water_ringout(event: Dictionary, arena_radius: float, decor_lake: bool) -> bool:
	if WATER_ZONES.has(String(event.get("zone", ""))):
		return true
	return decor_lake and is_over_lake(event["pos"], arena_radius)
