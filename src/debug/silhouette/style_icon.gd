class_name StyleIcon
extends RefCounted
## Small floating 3D style mark for mockup direction C (Phase 5 T8 gate), facing +Z: a fist
## (boxing), a sword (weapon) or a fireball (ranged). Built from primitives, tokens only.

## No badge disc behind the mark: the mark itself must survive the silhouette test.
const MARK_SCALE := 1.7


static func build(style: int) -> Node3D:
	var mark := Node3D.new()
	mark.scale = Vector3.ONE * MARK_SCALE
	match style:
		StyleMockup.Style.BOXING:
			_fist(mark)
		StyleMockup.Style.WEAPON:
			_sword(mark)
		StyleMockup.Style.RANGED:
			_fireball(mark)
	return mark


## A boxing glove: round mitt, thumb bump on the side, cream cuff below.
static func _fist(mark: Node3D) -> void:
	var mat := StyleMockup.glow_material(DS.DANGER)
	mark.add_child(StyleMockup.mesh_node(StyleMockup.sphere(0.13), mat, Vector3(0.0, 0.03, 0.0)))
	mark.add_child(StyleMockup.mesh_node(StyleMockup.sphere(0.065), mat, Vector3(-0.12, -0.02, 0.02)))
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.085
	cuff.bottom_radius = 0.085
	cuff.height = 0.09
	mark.add_child(StyleMockup.mesh_node(cuff, StyleMockup.glow_material(DS.UI_SURFACE_DIM), Vector3(0.02, -0.14, 0.0)))


static func _sword(mark: Node3D) -> void:
	var holder := Node3D.new()
	holder.rotation_degrees.z = -40.0
	mark.add_child(holder)
	holder.add_child(_box(Vector3(0.06, 0.28, 0.02), DS.PETAL_BLUE, Vector3(0.0, 0.05, 0.0)))
	holder.add_child(_box(Vector3(0.2, 0.04, 0.03), DS.DIRT, Vector3(0.0, -0.1, 0.0)))
	holder.add_child(_box(Vector3(0.04, 0.09, 0.03), DS.BARK, Vector3(0.0, -0.16, 0.0)))


static func _fireball(mark: Node3D) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.1
	cone.height = 0.2
	var tail := StyleMockup.mesh_node(cone, StyleMockup.glow_material(DS.FIRE), Vector3(0.08, 0.08, -0.01))
	tail.rotation_degrees.z = -45.0
	mark.add_child(tail)
	mark.add_child(StyleMockup.mesh_node(StyleMockup.sphere(0.11), StyleMockup.glow_material(DS.FIRE), Vector3(-0.03, -0.03, 0.0)))
	mark.add_child(StyleMockup.mesh_node(StyleMockup.sphere(0.06), StyleMockup.glow_material(DS.GLOW), Vector3(-0.03, -0.03, 0.06)))


static func _box(size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return StyleMockup.mesh_node(box, StyleMockup.glow_material(color), at)
