class_name IceFloorMesh
extends RefCounted
## Ice floors (frozen pond, design.md DS-VIS-04): slabs for boxes and a thick ice ring for ring
## shapes, a snow-white top over pale-blue ice walls (theme floor_top / rim) with a pale-blue lip
## along the ring's outer edge so the ring-out edge reads from the high camera. FloorMesh.build
## hands boxes (on ice themes) and rings here. The node's origin is the shape center; its top is
## center.y. Slabs that overlap the ring share its top height and color, so the seams never show.

const THICKNESS := 1.0
const SEGMENTS := 72


static func build(shape: Dictionary, theme: ArenaTheme) -> Node3D:
	var root := Node3D.new()
	root.position = shape["center"]
	root.rotation.y = float(shape["yaw"])
	if int(shape["kind"]) == ArenaShape.Kind.RING:
		ring(root, float(shape["radius"]), float(shape["inner"]), theme)
	else:
		slab(root, (shape["half"] as Vector2) * 2.0, theme.floor_top, theme.rim)
	return root


## A box of ice, size = (x, z): a top slab over a wall block down to `thickness`.
static func slab(root: Node3D, size: Vector2, top_color: Color, wall_color: Color, thickness: float = THICKNESS) -> void:
	var top := BoxMesh.new()
	top.size = Vector3(size.x, FloorMesh.TOP_THICKNESS, size.y)
	_add(root, top, top_color, Vector3(0, -FloorMesh.TOP_THICKNESS * 0.5, 0))
	var wall_box := BoxMesh.new()
	var depth := maxf(thickness - FloorMesh.TOP_THICKNESS, 0.01)
	wall_box.size = Vector3(size.x, depth, size.y)
	_add(root, wall_box, wall_color, Vector3(0, -FloorMesh.TOP_THICKNESS - depth * 0.5, 0))


## A thick ice ring from inner to outer radius with a lip along the outer edge.
static func ring(root: Node3D, outer: float, inner: float, theme: ArenaTheme) -> void:
	_add(root, annulus(outer, inner), theme.floor_top, Vector3.ZERO)
	_add(root, wall(outer, THICKNESS, true), theme.rim, Vector3.ZERO)
	_add(root, wall(inner, THICKNESS, false), theme.rim, Vector3.ZERO)
	var lip := TorusMesh.new()
	lip.inner_radius = outer - FloorMesh.LIP_WIDTH
	lip.outer_radius = outer
	lip.rings = SEGMENTS
	var mi := _add(root, lip, theme.floor_lip, Vector3(0, FloorMesh.LIP_LIFT, 0))
	mi.scale = Vector3(1.0, FloorMesh.LIP_FLATTEN, 1.0)


## Flat annulus at y = 0 facing up.
static func annulus(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k: int in SEGMENTS:
		var a0 := _dir(k)
		var a1 := _dir(k + 1)
		_tri(st, a0 * inner, a0 * outer, a1 * outer)
		_tri(st, a0 * inner, a1 * outer, a1 * inner)
	return st.commit()


## Vertical cylinder wall from y = 0 down to -height, facing out (or in, toward the center).
static func wall(r: float, height: float, facing_out: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var down := Vector3(0, -height, 0)
	var side := 1.0 if facing_out else -1.0
	for k: int in SEGMENTS:
		var t0 := _dir(k) * r
		var t1 := _dir(k + 1) * r
		var corners: Array = [t0, t0 + down, t1 + down, t0, t1 + down, t1] if facing_out \
				else [t0, t1, t1 + down, t0, t1 + down, t0 + down]
		for v: Vector3 in corners:
			st.set_normal(Vector3(v.x, 0.0, v.z).normalized() * side)  # smooth around the ring
			st.add_vertex(v)
	return st.commit()


static func _dir(k: int) -> Vector3:
	var a := TAU * float(k) / SEGMENTS
	return Vector3(cos(a), 0.0, sin(a))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _add(root: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color)
	mi.position = pos
	root.add_child(mi)
	return mi
