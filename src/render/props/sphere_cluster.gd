class_name SphereCluster
extends Node3D
## Bush or tree canopy made of overlapping spheres (design.md DS-VIS-02 form language).

## x, y, z, radius of each sphere at size 1.
const LAYOUT := [
	Vector4(0.0, 0.9, 0.0, 0.9), Vector4(-0.8, 0.6, 0.2, 0.65), Vector4(0.8, 0.6, 0.1, 0.7),
	Vector4(-0.3, 1.4, -0.3, 0.6), Vector4(0.4, 1.3, 0.4, 0.55), Vector4(0.1, 0.5, 0.8, 0.6),
]
const TRUNK_RADIUS := 0.18
const SPHERE_SEGMENTS := 24
const SPHERE_RINGS := 12


func setup(color: Color, size: float, p_seed: int, trunk_height: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = SPHERE_SEGMENTS
	sphere.rings = SPHERE_RINGS
	var material := ToonMaterials.toon(color)

	if trunk_height > 0.0:
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = TRUNK_RADIUS * size
		cyl.bottom_radius = TRUNK_RADIUS * size
		cyl.height = trunk_height * size
		trunk.mesh = cyl
		trunk.material_override = ToonMaterials.toon(DS.BARK)
		trunk.position.y = trunk_height * size * 0.5
		add_child(trunk)

	for s: Vector4 in LAYOUT:
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = material
		mi.position = Vector3(s.x, s.y + trunk_height, s.z) * size
		mi.scale = Vector3.ONE * s.w * size * rng.randf_range(0.9, 1.1)
		add_child(mi)
