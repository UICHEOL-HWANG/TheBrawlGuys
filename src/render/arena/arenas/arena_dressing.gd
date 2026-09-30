class_name ArenaDressing
extends Node3D
## Per-arena set dressing outside the fight area (PRD §6.1: large decor stays outside the arena,
## design.md DS-VIS-04). Each arena has one subclass file: it builds its own set pieces in
## _build() and tells DecorView where scattered props may stand (prop_ground) and what they are
## (make_prop). Every tall piece is registered as an occluder so DecorOcclusion can prove the
## match camera always sees the arena core (GD-CAM-01).

## Props never stand closer than this to a ring-out zone (lake shore).
const ZONE_MARGIN := 1.5
const TREE_EVERY := 3
const TREE_TRUNK := 1.2
const TREE_SIZE := 1.6
const PROP_HEIGHT_PER_SIZE := 2.2

var _arena: ArenaData
var _theme: ArenaTheme
var _config: GameConfig
var _rng := RandomNumberGenerator.new()
## {node: Node3D, radius: float, height: float, drop: float (node origin above the base)}
var _occluders: Array[Dictionary] = []


func setup(arena: ArenaData, theme: ArenaTheme, config: GameConfig, p_seed: int) -> void:
	_arena = arena
	_theme = theme
	_config = config
	_rng.seed = p_seed
	_build()


## Ground height a scattered prop may stand on at p, or NAN where none may stand.
func prop_ground(p: Vector3) -> float:
	for z: ArenaShape in _arena.ringout_zones:
		if z.kind == ArenaShape.Kind.CIRCLE and z.edge_distance(p) > -ZONE_MARGIN:
			return NAN
	return DecorView.GROUND_Y


## A scattered prop (the i-th) and its occluder size {node, radius, height}.
func make_prop(rng: RandomNumberGenerator, i: int) -> Dictionary:
	var is_tree := i % TREE_EVERY == 0
	var size := rng.randf_range(0.9, 1.4) * (TREE_SIZE if is_tree else 1.0)
	var prop := SphereCluster.new()
	prop.setup(_theme.canopy if is_tree else _theme.bush, size, rng.randi(), TREE_TRUNK if is_tree else 0.0)
	var height := size * PROP_HEIGHT_PER_SIZE + (TREE_TRUNK * size if is_tree else 0.0)
	return {"node": prop, "radius": size, "height": height}


## The classic meadow lake at +x (splash ring-outs, DecorView.is_over_lake).
func has_decor_lake() -> bool:
	return false


## Flower dots on the arena floor itself (round grass arenas).
func inner_flowers() -> bool:
	return _arena.floors[0].kind == ArenaShape.Kind.CIRCLE


func occluders() -> Array[Dictionary]:
	return _occluders


## centered: the node's origin sits at half height (primitive meshes), not at its base.
func add_occluder(node: Node3D, radius: float, height: float, centered: bool = false) -> void:
	_occluders.append({"node": node, "radius": radius, "height": height,
		"drop": height * 0.5 if centered else 0.0})


func _build() -> void:
	pass


func _piece(mesh: Mesh, color: Color, pos: Vector3, rim: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color, rim)
	mi.position = pos
	add_child(mi)
	return mi
