class_name ImpactBurst
extends Node3D
## Comic hit impact v2 (design.md DS-VFX-01, user request 2026-09-30 "겟앰프드처럼"): a flat
## spiky star facing the camera (dark ink rim, the attacker's player color, a hot core), a shock
## ring whose plane faces the hit direction, and on heavy hits radial speed lines. It pops in at
## once, holds through hitstop, then shrinks and fades. play_clang() is the guard version
## (DS-VFX-07): small flat blue needles and ring, no star. play_perfect() replaces the clang on a
## perfect guard (DS-VFX-13): a bigger, longer white star with an ink rim, white needles and
## ring. Pooled: FeelDirector reuses nodes.

const STAR_INNER := 0.42
const CORE_INNER := 0.5
const INK_SCALE := 1.16
const CORE_SCALE := 0.5
const POP_TIME := 0.05
const POP_FROM := 0.55
const MIN_HOLD := 0.05
const FADE_TIME := 0.14
const END_SCALE := 0.35
const RING_FROM := 0.5
const RING_TO := 2.4
const NEEDLE_FROM := 1.2
const NEEDLE_TO := 2.8
const CLANG_RADIUS := 0.9
const CLANG_NEEDLES := 8
const CLANG_NEEDLE_WIDTH := 0.09
const CLANG_FADE := 0.14
const PERFECT_POINTS := 8
const PERFECT_RADIUS := 1.3
const PERFECT_NEEDLES := 12
const PERFECT_FADE := 0.26

var _face: Node3D
var _ink: MeshInstance3D
var _color: MeshInstance3D
var _core: MeshInstance3D
var _needles: MeshInstance3D
var _ring: MeshInstance3D
var _age: float = 0.0
var _hold: float = 0.0
var _fade: float = FADE_TIME
var _radius: float = 1.0
var _roll: float = 0.0
var _dir: Vector3 = Vector3.RIGHT
var _active: bool = false
## Layers that fade together / the star layers (members: advance() runs every frame).
var _fading: Array[MeshInstance3D] = []
var _star_layers: Array[MeshInstance3D] = []


func _init() -> void:
	_face = Node3D.new()
	add_child(_face)
	_ink = _layer(_face, 0)
	_color = _layer(_face, 1)
	_needles = _layer(_face, 1)
	_core = _layer(_face, 2)
	_ring = _layer(self, 1)
	_ring.mesh = StarShape.ring_mesh()
	_fading.assign([_ink, _color, _core, _needles])
	_star_layers.assign([_ink, _color, _core])
	visible = false


## A landed hit: star size and spikes from the tier, color from the attacker, needles on heavy.
func play_hit(at: Vector3, dir: Vector3, tier: int, color: Color, hold: float, lines: int, roll: float) -> void:
	var points := ImpactTier.star_points(tier)
	_ink.mesh = StarShape.star_mesh(points, STAR_INNER)
	_color.mesh = _ink.mesh
	_core.mesh = StarShape.star_mesh(points, CORE_INNER)
	_tint(_ink, DS.CANOPY_DEEP)
	_tint(_color, color)
	_tint(_core, DS.IMPACT_CORE)
	_tint(_ring, DS.IMPACT_CORE)
	_needles.visible = lines > 0
	if lines > 0:
		_needles.mesh = StarShape.needle_mesh(lines)
		_tint(_needles, DS.UI_SURFACE)
	_start(at, dir, ImpactTier.burst_radius(tier), hold, FADE_TIME, roll, true)


## A guarded hit: a small flat blue clang, no star.
func play_clang(at: Vector3, dir: Vector3, hold: float, roll: float) -> void:
	_needles.mesh = StarShape.needle_mesh(CLANG_NEEDLES, CLANG_NEEDLE_WIDTH)
	_needles.visible = true
	_tint(_needles, DS.PETAL_BLUE)
	_tint(_ring, DS.CLANG)
	_start(at, dir, CLANG_RADIUS, hold, CLANG_FADE, roll, false)


## A perfect guard: a big white star flash with an ink rim in place of the clang.
func play_perfect(at: Vector3, dir: Vector3, hold: float, roll: float) -> void:
	_ink.mesh = StarShape.star_mesh(PERFECT_POINTS, STAR_INNER)
	_color.mesh = _ink.mesh
	_core.mesh = StarShape.star_mesh(PERFECT_POINTS, CORE_INNER)
	_tint(_ink, DS.CANOPY_DEEP)
	_tint(_color, DS.WHITE)
	_tint(_core, DS.CLANG)
	_needles.mesh = StarShape.needle_mesh(PERFECT_NEEDLES)
	_needles.visible = true
	_tint(_needles, DS.WHITE)
	_tint(_ring, DS.WHITE)
	_start(at, dir, PERFECT_RADIUS, hold, PERFECT_FADE, roll, true)


func radius() -> float:
	return _radius


func stop() -> void:
	_active = false
	visible = false


func active() -> bool:
	return _active


func star_visible() -> bool:
	return _active and _color.visible


func _process(delta: float) -> void:
	if _active:
		advance(delta)


func advance(delta: float) -> void:
	_age += delta
	var life := _hold + _fade
	if _age >= life:
		_active = false
		visible = false
		return
	_face_camera()
	var fade := clampf((_age - _hold) / _fade, 0.0, 1.0)
	var pop := lerpf(POP_FROM, 1.0, minf(_age / POP_TIME, 1.0))
	var star := _radius * pop * lerpf(1.0, END_SCALE, fade * fade)
	_ink.scale = Vector3.ONE * star * INK_SCALE
	_color.scale = Vector3.ONE * star
	_core.scale = Vector3.ONE * star * CORE_SCALE
	var t := _age / life
	_needles.scale = Vector3.ONE * _radius * lerpf(NEEDLE_FROM, NEEDLE_TO, t)
	_ring.basis = Basis.looking_at(_dir, Vector3.UP).scaled(Vector3.ONE * _radius * lerpf(RING_FROM, RING_TO, t))
	var alpha := 1.0 - fade
	for mi: MeshInstance3D in _fading:
		_set_alpha(mi, alpha)
	_set_alpha(_ring, (1.0 - t) * 0.9)


func _start(at: Vector3, dir: Vector3, radius: float, hold: float, fade: float, roll: float, star: bool) -> void:
	position = at
	_dir = dir if dir.length() > 0.0 else Vector3.RIGHT
	_radius = radius
	_hold = maxf(hold, MIN_HOLD)
	_fade = fade
	_roll = roll
	_age = 0.0
	for mi: MeshInstance3D in _star_layers:
		mi.visible = star
	_active = true
	visible = true
	advance(0.0)


## The star plane faces the current camera, rolled so repeated hits do not look stamped.
func _face_camera() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_face.global_basis = cam.global_basis.orthonormalized() * Basis(Vector3.BACK, _roll)


## An unshaded, see-through, always-on-top flat layer with its own material (fades per burst).
static func _layer(parent: Node3D, priority: int) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = priority
	var mi := MeshInstance3D.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _tint(mi: MeshInstance3D, color: Color) -> void:
	(mi.material_override as StandardMaterial3D).albedo_color = color


static func _set_alpha(mi: MeshInstance3D, alpha: float) -> void:
	var mat := mi.material_override as StandardMaterial3D
	var c := mat.albedo_color
	c.a = clampf(alpha, 0.0, 1.0)
	mat.albedo_color = c
