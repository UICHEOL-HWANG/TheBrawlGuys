class_name DizzyStars
extends Node3D
## Guard-break dizzy stars (design.md DS-VFX-12, GetAmped style): flat petal_yellow stars with a
## dark canopy_deep ink rim, always facing the camera and drawn on top, circling well above the
## head so they read from the top-down camera over the yellow floor flowers.

const COUNT := 3
const RADIUS := 0.22
const POINTS := 5
const INNER := 0.5
const INK_SCALE := 1.35
const ORBIT := 0.42
const LIFT := 0.45
const SPIN_HZ := 1.2

static var _ink: StandardMaterial3D = null
static var _fill: StandardMaterial3D = null


func setup(config: GameConfig) -> void:
	position.y = config.fighter_height + LIFT
	visible = false
	if _ink == null:
		_ink = _material(DS.CANOPY_DEEP, 0)
		_fill = _material(DS.PETAL_YELLOW, 1)
	var mesh := StarShape.star_mesh(POINTS, INNER)
	for i: int in COUNT:
		var star := Node3D.new()
		var angle := TAU * float(i) / COUNT
		star.position = Vector3(cos(angle), 0.0, sin(angle)) * ORBIT
		add_child(star)
		_layer(star, mesh, _ink, RADIUS * INK_SCALE)
		_layer(star, mesh, _fill, RADIUS)


## Every frame: shown while the guard is broken, spinning with the clock `time`.
func advance(shown: bool, time: float) -> void:
	visible = shown
	if shown:
		rotation.y = time * TAU * SPIN_HZ


static func _layer(parent: Node3D, mesh: Mesh, mat: Material, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3.ONE * radius
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Unshaded camera-facing layer on top of the scene; the ink draws first (lower priority).
static func _material(color: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = true
	mat.render_priority = priority
	mat.albedo_color = color
	return mat
