class_name TallMushroom
extends Node3D
## Giant decor mushroom for the mushroom forest (design.md DS-VIS-02 round forms, DS-THM-02
## self-glowing caps): a cream stem with a soft bulge, a domed cap in a glowing accent and light
## spots. Origin at the stem foot.

const STEM_RADIUS := 0.35
const CAP_RADIUS := 1.3
const CAP_HEIGHT := 1.1
const SPOT_RADIUS := 0.2
const SPOT_COUNT := 5


## Returns the total height (for occlusion checks).
func setup(cap_color: Color, size: float, p_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var stem_h := size * rng.randf_range(1.6, 2.4)
	var stem := CylinderMesh.new()
	stem.top_radius = STEM_RADIUS * size * 0.8
	stem.bottom_radius = STEM_RADIUS * size
	stem.height = stem_h
	_add(stem, DS.STONE_CREAM, Vector3(0, stem_h * 0.5, 0), 0.0)
	var cap := SphereMesh.new()
	cap.radius = CAP_RADIUS * size
	cap.height = CAP_HEIGHT * size
	_add(cap, cap_color, Vector3(0, stem_h, 0), 0.5)
	var spot := SphereMesh.new()
	spot.radius = SPOT_RADIUS * size
	spot.height = SPOT_RADIUS * size
	for i: int in SPOT_COUNT:
		var a := TAU * float(i) / SPOT_COUNT + rng.randf() * 0.5
		var r := CAP_RADIUS * size * 0.55
		_add(spot, DS.GLOW, Vector3(cos(a) * r, stem_h + CAP_HEIGHT * size * 0.33, sin(a) * r), 0.0)
	return stem_h + CAP_HEIGHT * size * 0.5


func _add(mesh: Mesh, color: Color, pos: Vector3, rim: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color, rim)
	mi.position = pos
	add_child(mi)
