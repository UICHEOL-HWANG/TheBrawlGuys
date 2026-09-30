class_name DecorView
extends Node3D
## Outer meadow, lake, rock, bushes, trees and flowers around the arena.
## Large props (rock, bushes, trees, lake) stay outside the ring (design.md DS-VIS-04);
## flower patches are floor decals and may lie inside it. Re-lays out when arena_radius changes.

const GROUND_Y := -1.0
const GROUND_SIZE := 400.0
const PROP_COUNT := 14
const FLOWER_COUNT := 24
const LAKE_RADIUS := 12.0
const LAKE_OFFSET := 14.0
const LAKE_SEGMENTS := 48
const ROCK_SCALE := Vector3(1.6, 1.1, 1.3)
const FLOWER_COLORS := [DS.PETAL_PINK, DS.PETAL_BLUE, DS.PETAL_YELLOW]

var _config: GameConfig
## Each item: {"node": Node3D, "angle": float, "y": float, and either "offset" (outside ring) or "frac" (inside)}
var _items: Array[Dictionary] = []


func setup(config: GameConfig, p_seed: int) -> void:
	_config = config
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	_add_ground()
	_add_lake()
	_add_rock()
	for i: int in PROP_COUNT:
		var is_tree := i % 3 == 0
		var prop := SphereCluster.new()
		add_child(prop)
		var size := rng.randf_range(0.9, 1.4) * (1.6 if is_tree else 1.0)
		prop.setup(DS.CANOPY if is_tree else DS.GRASS_MID, size, rng.randi(), 1.2 if is_tree else 0.0)
		_items.append({"node": prop, "angle": TAU * i / PROP_COUNT + rng.randf_range(-0.15, 0.15), "offset": rng.randf_range(2.5, 6.0), "y": GROUND_Y})
	for i: int in FLOWER_COUNT:
		var patch := FlowerPatch.new()
		add_child(patch)
		patch.setup(FLOWER_COLORS[i % FLOWER_COLORS.size()], rng.randi())
		var inside := i % 2 == 0
		var item := {"node": patch, "angle": rng.randf_range(0.0, TAU), "y": 0.0 if inside else GROUND_Y}
		if inside:
			item["frac"] = rng.randf_range(0.15, 0.85)
		else:
			item["offset"] = rng.randf_range(1.0, 8.0)
		_items.append(item)
	_config.changed.connect(_layout)
	_layout()


func _layout() -> void:
	var r := _config.arena_radius
	for item: Dictionary in _items:
		var node: Node3D = item["node"]
		var angle: float = item["angle"]
		var dist: float = r * float(item["frac"]) if item.has("frac") else r + float(item["offset"])
		node.position = Vector3(cos(angle) * dist, float(item["y"]), sin(angle) * dist)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane
	mi.material_override = ToonMaterials.toon(DS.GRASS_MID)
	mi.position.y = GROUND_Y
	add_child(mi)


func _add_lake() -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS
	disc.bottom_radius = LAKE_RADIUS
	disc.height = 0.1
	disc.radial_segments = LAKE_SEGMENTS
	mi.mesh = disc
	mi.material_override = ToonMaterials.toon(DS.WATER)
	add_child(mi)
	_items.append({"node": mi, "angle": 0.0, "offset": LAKE_OFFSET, "y": GROUND_Y + 0.05})


func _add_rock() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.scale = ROCK_SCALE
	mi.material_override = ToonMaterials.toon(DS.STONE_CREAM)
	add_child(mi)
	_items.append({"node": mi, "angle": PI * 0.75, "offset": 4.0, "y": GROUND_Y + 0.6})


## True when a point is horizontally over the lake (ring-outs there splash, DS-VFX-05).
static func is_over_lake(pos: Vector3, arena_radius: float) -> bool:
	return Vector2(pos.x - (arena_radius + LAKE_OFFSET), pos.z).length() <= LAKE_RADIUS
