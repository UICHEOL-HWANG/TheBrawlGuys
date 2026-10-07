class_name GripPop
extends Node3D
## The grab-connect pop (combat-motion B3): a ring in the grabber's color snaps shut around the
## victim's chest (closing in reads as "caught"), then a small inked star pops at the grip and
## everything fades. Faces the camera and draws over bodies. Pooled by GrabFx.

const LIFE := 0.42
## The ring closes from RING_FROM to RING_TO (m) in the first CLOSE_SHARE of the life.
const RING_FROM := 1.9
const RING_TO := 0.6
const CLOSE_SHARE := 0.32
const STAR_POINTS := 5
const STAR_INNER := 0.45
const STAR_SIZE := 0.55
const INK_SCALE := 1.22

var _face: Node3D
var _ring: MeshInstance3D
var _ink: MeshInstance3D
var _star: MeshInstance3D
var _age: float = LIFE
var _active: bool = false


func _init() -> void:
	_face = Node3D.new()
	add_child(_face)
	_ring = FxMaterials.attach(_face, StarShape.ring_mesh(), DS.WHITE, true, 3)
	_ink = FxMaterials.attach(_face, StarShape.star_mesh(STAR_POINTS, STAR_INNER), DS.CANOPY_DEEP, true, 4)
	_star = FxMaterials.attach(_face, StarShape.star_mesh(STAR_POINTS, STAR_INNER), DS.WHITE, true, 5)
	visible = false


func play(at: Vector3, color: Color) -> void:
	position = at
	FxMaterials.tint(_ring, color)
	FxMaterials.tint(_star, color)
	_age = 0.0
	_active = true
	visible = true
	advance(0.0)


func advance(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if _age >= LIFE:
		_active = false
		visible = false
		return
	_face_camera()
	var t := _age / LIFE
	var close := minf(t / CLOSE_SHARE, 1.0)
	_ring.scale = Vector3.ONE * lerpf(RING_FROM, RING_TO, close * close)
	var pop := clampf((t - CLOSE_SHARE * 0.7) / 0.2, 0.0, 1.0)
	var star := STAR_SIZE * (pop + 0.3 * sin(pop * PI)) * lerpf(1.0, 0.7, t)
	_star.scale = Vector3.ONE * maxf(star, 0.001)
	_ink.scale = _star.scale * INK_SCALE
	var fade := 1.0 - smoothstep(0.55, 1.0, t)
	FxMaterials.set_alpha(_ring, fade)
	FxMaterials.set_alpha(_star, fade)
	FxMaterials.set_alpha(_ink, fade)


func active() -> bool:
	return _active


func _face_camera() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_face.global_basis = cam.global_basis.orthonormalized()
