class_name RockModel
extends ItemModel
## Throwing rock (design.md DS-VIS-05, Phase 4 T8): a squashed, jittered icosahedron with flat
## facets in the cream stone of the arena rocks, plus a small shaded chip. Tumbles while it
## flies. Origin on the ground under the stone.

const RADIUS := 0.26
const SQUASH := Vector3(1.0, 0.72, 0.88)
## Per-vertex radius jitter (fixed so every rock looks the same and tests stay stable).
const JITTER: Array[float] = [1.0, 0.86, 1.08, 0.93, 1.05, 0.9, 1.1, 0.95, 0.88, 1.04, 0.97, 1.07]
const CHIP_RADIUS := 0.09
## Tumble speed in flight (radians per sim tick).
const SPIN_PER_TICK := 0.3
## In the palm, just outside the hand (handslot.r axes as in BombModel.HOLD: -x up, +z outward).
const HOLD := Transform3D(Vector3(0, 0.85, 0), Vector3(-0.85, 0, 0), Vector3(0, 0, 0.85), Vector3(0.16, 0, 0.17))

static var _mesh: ArrayMesh = null

var _pivot: Node3D


## Flat-shaded jittered icosahedron (one normal per face, three vertices per triangle).
static func faceted_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var verts := _ico_vertices()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Vector3i in _ico_faces():
		var a := verts[f.x]
		var b := verts[f.y]
		var c := verts[f.z]
		st.set_normal((b - a).cross(c - a).normalized())  # faces list counter-clockwise from outside
		for v: Vector3 in [a, c, b]:  # Godot front faces wind clockwise
			st.add_vertex(v)
	_mesh = st.commit()
	return _mesh


static func _ico_vertices() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var raw := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	var out := PackedVector3Array()
	for i: int in raw.size():
		out.append(raw[i].normalized() * RADIUS * JITTER[i] * SQUASH)
	return out


static func _ico_faces() -> Array[Vector3i]:
	return [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
		Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2),
		Vector3i(10, 7, 6), Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2),
		Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9), Vector3i(4, 9, 5),
		Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]


func show_state(view: Dictionary, tick: int) -> void:
	var flying := int(view.get("state", Item.State.GROUND)) == Item.State.THROWN
	_pivot.rotation.x = wrapf(tick * SPIN_PER_TICK, 0.0, TAU) if flying else 0.0


func spin_angle() -> float:
	return _pivot.rotation.x


func hold_transform() -> Transform3D:
	return HOLD


func _build() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = RADIUS * SQUASH.y
	add_child(_pivot)
	_part(faceted_mesh(), DS.STONE_CREAM, Transform3D.IDENTITY, _pivot)
	_part(ItemParts.sphere(CHIP_RADIUS, CHIP_RADIUS * 1.2, 6), DS.STONE_SHADE,
			ItemParts.at(Vector3(0.12, -0.06, 0.1)), _pivot)
