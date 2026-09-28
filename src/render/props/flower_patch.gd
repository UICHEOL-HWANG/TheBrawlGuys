class_name FlowerPatch
extends Node3D
## A small cluster of colored dots on the grass (reference A "꽃 점").

const DOT_RADIUS := 0.18
const DOT_HEIGHT := 0.03
const DOT_SEGMENTS := 8
const SPREAD := 0.8


func setup(color: Color, p_seed: int, count: int = 5) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var dot := CylinderMesh.new()
	dot.top_radius = DOT_RADIUS
	dot.bottom_radius = DOT_RADIUS
	dot.height = DOT_HEIGHT
	dot.radial_segments = DOT_SEGMENTS
	var material := ToonMaterials.toon(color)
	for i: int in count:
		var mi := MeshInstance3D.new()
		mi.mesh = dot
		mi.material_override = material
		mi.position = Vector3(rng.randf_range(-SPREAD, SPREAD), DOT_HEIGHT * 0.5, rng.randf_range(-SPREAD, SPREAD))
		add_child(mi)
