class_name StyleGearParts
extends RefCounted
## Mesh builders for StyleGear (design.md DS-VIS-02): round boxing gloves with a cuff, the fire
## orb on the staff head, and the tilt that leans the sword / staff back over the shoulder so
## they cover neighbours less in a crowded fight. Colors only from DS tokens.

const GLOVE_ROUGHNESS := 0.35
const CUFF_RATIO := 0.72
const CUFF_OFFSET := -0.7
const ORB_RADIUS := 0.13
const ORB_CORE_RATIO := 0.55


## A glove sized in world metres; the caller undoes the bone slot's scale.
static func glove(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "StyleGlove"
	root.add_child(_mesh_node(_sphere(radius), ToonMaterials.toon(DS.DANGER, GLOVE_ROUGHNESS)))
	root.add_child(_mesh_node(_sphere(radius * CUFF_RATIO), ToonMaterials.toon(DS.UI_SURFACE, GLOVE_ROUGHNESS),
			Vector3(0.0, radius * CUFF_OFFSET, 0.0)))
	return root


## A glowing fire orb at the staff's head (far end of its longest axis, by the gem).
## world_scale: the staff's world scale, undone so the orb keeps ORB_RADIUS in metres.
static func orb(staff: MeshInstance3D, world_scale: float) -> Node3D:
	var box := staff.get_aabb()
	var axis := box.get_longest_axis_index()
	var tip := box.get_center()
	tip[axis] = box.end[axis]
	var root := Node3D.new()
	root.name = "StyleOrb"
	root.position = tip
	root.scale = Vector3.ONE / maxf(world_scale, 0.0001)
	root.add_child(_mesh_node(_sphere(ORB_RADIUS), _glow(DS.FIRE)))
	root.add_child(_mesh_node(_sphere(ORB_RADIUS * ORB_CORE_RATIO), _glow(DS.GLOW)))
	staff.add_child(root)
	return root


## `rest` turned about the hand slot's origin (the grip): x by degrees.x, then z by degrees.y,
## and scaled there.
static func tilted(rest: Transform3D, degrees: Vector2, grow: float = 1.0) -> Transform3D:
	var turn := Basis(Vector3.BACK, deg_to_rad(degrees.y)) * Basis(Vector3.RIGHT, deg_to_rad(degrees.x))
	turn = turn.scaled(Vector3.ONE * grow)
	return Transform3D(turn, Vector3.ZERO) * rest


static func _glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


static func _mesh_node(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return node


static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s
