class_name PerfectRing
extends Node3D
## Perfect-guard ring (design.md DS-VFX-13): a bright white ring over a thicker canopy_deep ink
## ring bursts out from the fighter's body and fades over LIFE. Built once and replayed (no
## allocation per flash). FeelDirector adds the white star flash at the contact point in place
## of the guard clang.

const LIFE := DS.MOTION_SLOW
const INNER_RATIO := 1.1
const OUTER_RATIO := 1.4
## Extra tube thickness of the ink ring around the white one.
const INK_PAD := 0.05
const START_SCALE := 0.6
const END_SCALE := 2.6

var _ink: MeshInstance3D
var _glow: MeshInstance3D
var _age: float = LIFE


func setup(config: GameConfig) -> void:
	position.y = config.fighter_height * 0.5
	visible = false
	var r := config.fighter_radius
	_ink = _ring(r * INNER_RATIO - INK_PAD, r * OUTER_RATIO + INK_PAD, DS.CANOPY_DEEP, 0)
	_glow = _ring(r * INNER_RATIO, r * OUTER_RATIO, DS.WHITE, 1)


func play() -> void:
	_age = 0.0
	visible = true
	advance(0.0)


## Every frame: grows with an ease-out and fades; hides itself after LIFE.
func advance(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if _age >= LIFE:
		visible = false
		return
	var t := _age / LIFE
	scale = Vector3.ONE * lerpf(START_SCALE, END_SCALE, 1.0 - (1.0 - t) * (1.0 - t))
	var alpha := 1.0 - t * t
	_set_alpha(_ink, alpha)
	_set_alpha(_glow, alpha)


func _ring(inner: float, outer: float, color: Color, priority: int) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # the ink tube encloses the white one: draw order, not depth
	mat.render_priority = priority
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _set_alpha(mi: MeshInstance3D, alpha: float) -> void:
	var mat := mi.material_override as StandardMaterial3D
	var c := mat.albedo_color
	c.a = alpha
	mat.albedo_color = c
