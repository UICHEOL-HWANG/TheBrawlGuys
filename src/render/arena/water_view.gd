class_name WaterView
extends Node3D
## Water under the arena's ring-out zones (design.md DS-VIS-04: the ring-out side reads as water):
## a lake disc with a deeper middle for circle zones, a wide river sheet for box zones, both at
## the zone's water line, with a few sun glints that drift and twinkle (DS-THM-02 물 반짝임).

const DISC_HEIGHT := 0.1
const SEGMENTS := 48
const DEEP_RATIO := 0.6
const DEEP_LIFT := 0.01
const GLINT_COUNT := 8
const GLINT_RADIUS := 0.35
const GLINT_LIFT := 0.03
const GLINT_FLATTEN := 0.25
const GLINT_HZ := 0.6

var _glints: Array[MeshInstance3D] = []
var _time: float = 0.0


func setup(zones: Array[Dictionary], theme: ArenaTheme, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for z: Dictionary in zones:
		var at: Vector3 = z["center"]
		if int(z["kind"]) == ArenaShape.Kind.CIRCLE:
			var r := float(z["radius"])
			_disc(at, r, theme.water)
			_disc(at + Vector3(0, DEEP_LIFT, 0), r * DEEP_RATIO, DS.WATER_DEEP)
			_add_glints(at, r * DEEP_RATIO, rng)
		else:
			var size := (z["half"] as Vector2) * 2.0
			var plane := PlaneMesh.new()
			plane.size = size
			_mesh(plane, theme.water, at)
			_add_glints(at, minf(size.x, size.y) * 0.15, rng)


func _process(delta: float) -> void:
	_time += delta
	for i: int in _glints.size():
		var s := 0.5 + 0.5 * sin(_time * TAU * GLINT_HZ + i * 1.7)
		_glints[i].scale = Vector3(s, GLINT_FLATTEN * s, s)


func glint_count() -> int:
	return _glints.size()


func _add_glints(center: Vector3, spread: float, rng: RandomNumberGenerator) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = GLINT_RADIUS
	sphere.height = GLINT_RADIUS * 2.0
	for i: int in GLINT_COUNT:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * spread
		var p := center + Vector3(cos(a) * d, GLINT_LIFT, sin(a) * d)
		_glints.append(_mesh(sphere, DS.GLOW, p))


func _disc(at: Vector3, r: float, color: Color) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = DISC_HEIGHT
	disc.radial_segments = SEGMENTS
	_mesh(disc, color, at + Vector3(0, -DISC_HEIGHT * 0.5, 0))


func _mesh(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color)
	mi.position = at
	add_child(mi)
	return mi
