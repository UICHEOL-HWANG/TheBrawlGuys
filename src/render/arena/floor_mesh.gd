class_name FloorMesh
extends RefCounted
## Builds one walkable arena floor from an ArenaShape view (ArenaShape.to_view) in theme colors
## (design.md DS-VIS-04). Circles are a grass disc over a thick flared dirt rim with a bright lip
## so the ring-out edge reads from the high camera; boxes are a deck of cross boards over a beam
## (log bridge). The node's origin is the shape center; its top sits at center.y.

const TOP_THICKNESS := 0.2
const RIM_HEIGHT := 0.8
## >1 flares the rim outward below the grass edge so the dirt band shows from the high camera.
const RIM_TAPER := 1.08
const SEGMENTS := 64
const LIP_WIDTH := 0.3
const LIP_FLATTEN := 0.06
const LIP_LIFT := 0.005
## Box decks: board width along the long axis, the gap between boards, beam depth and inset.
const BOARD_WIDTH := 0.55
const BOARD_GAP := 0.06
const BEAM_HEIGHT := 0.45
const BEAM_INSET := 0.8


static func build(shape: Dictionary, theme: ArenaTheme) -> Node3D:
	var root := Node3D.new()
	root.position = shape["center"]
	root.rotation.y = float(shape["yaw"])
	if int(shape["kind"]) == ArenaShape.Kind.CIRCLE:
		_circle(root, float(shape["radius"]), theme)
	else:
		deck(root, (shape["half"] as Vector2) * 2.0, theme)
	return root


static func _circle(root: Node3D, r: float, theme: ArenaTheme) -> void:
	var top := CylinderMesh.new()
	top.top_radius = r
	top.bottom_radius = r
	top.height = TOP_THICKNESS
	top.radial_segments = SEGMENTS
	_add(root, top, theme.floor_top, Vector3(0, -TOP_THICKNESS * 0.5, 0))
	var rim := CylinderMesh.new()
	rim.top_radius = r
	rim.bottom_radius = r * RIM_TAPER
	rim.height = RIM_HEIGHT
	rim.radial_segments = SEGMENTS
	_add(root, rim, theme.rim, Vector3(0, -TOP_THICKNESS - RIM_HEIGHT * 0.5, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = r - LIP_WIDTH
	lip.outer_radius = r
	lip.rings = SEGMENTS
	var mi := _add(root, lip, theme.floor_lip, Vector3(0, LIP_LIFT, 0))
	mi.scale = Vector3(1.0, LIP_FLATTEN, 1.0)


## Cross boards along x (alternating two wood tones) over a beam, size = (length x, width z).
static func deck(root: Node3D, size: Vector2, theme: ArenaTheme) -> void:
	var count := maxi(roundi(size.x / BOARD_WIDTH), 1)
	var pitch := size.x / count
	for k: int in count:
		var board := BoxMesh.new()
		board.size = Vector3(pitch - BOARD_GAP, TOP_THICKNESS, size.y)
		var x := -size.x * 0.5 + pitch * (k + 0.5)
		var color := theme.floor_top if k % 2 == 0 else theme.floor_lip
		_add(root, board, color, Vector3(x, -TOP_THICKNESS * 0.5, 0))
	var beam := BoxMesh.new()
	beam.size = Vector3(size.x, BEAM_HEIGHT, maxf(size.y * BEAM_INSET, 0.1))
	_add(root, beam, theme.rim, Vector3(0, -TOP_THICKNESS - BEAM_HEIGHT * 0.5, 0))


static func _add(root: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color)
	mi.position = pos
	root.add_child(mi)
	return mi
