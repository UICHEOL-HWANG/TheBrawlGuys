class_name PineTree
extends Node3D
## Misty-forest conifer (design.md DS-VIS-02 stacked soft forms): a short bark trunk under three
## stacked rounded cones that shrink toward the top. Origin at the trunk foot.

const TRUNK_RADIUS := 0.2
const TRUNK_HEIGHT := 0.9
## Tiers: [radius, height, lift] at size 1, bottom to top.
const TIERS: Array[Vector3] = [Vector3(1.3, 1.6, 0.0), Vector3(1.0, 1.4, 0.9), Vector3(0.65, 1.2, 1.7)]
const SEGMENTS := 10


## Returns the total height (for occlusion checks).
func setup(color: Color, size: float) -> float:
	var trunk := CylinderMesh.new()
	trunk.top_radius = TRUNK_RADIUS * size
	trunk.bottom_radius = TRUNK_RADIUS * size
	trunk.height = TRUNK_HEIGHT * size
	_add(trunk, DS.BARK, Vector3(0, TRUNK_HEIGHT * size * 0.5, 0))
	var top := TRUNK_HEIGHT * size
	for t: Vector3 in TIERS:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05 * size
		cone.bottom_radius = t.x * size
		cone.height = t.y * size
		cone.radial_segments = SEGMENTS
		var y := TRUNK_HEIGHT * size + t.z * size + t.y * size * 0.5
		_add(cone, color, Vector3(0, y, 0))
		top = maxf(top, y + t.y * size * 0.5)
	return top


func _add(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color)
	mi.position = pos
	add_child(mi)
