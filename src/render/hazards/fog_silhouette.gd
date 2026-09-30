class_name FogSilhouette
extends Node3D
## A fighter seen through the fog (design.md DS-VIS-03: foot ring and silhouette stay visible
## over fog and shadows): a soft body silhouette and the foot ring in the player color, drawn on
## top of everything (no depth test, no fog) and faded in with the fog amount. Origin at the feet.

const BODY_ALPHA := 0.5
const RING_ALPHA := 0.9
const RING_INNER_RATIO := 1.15
const RING_OUTER_RATIO := 1.5
const RING_FLATTEN := 0.08
const RING_LIFT := 0.03
const RENDER_PRIORITY := 10

var _color: Color
var _body_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _amount: float = 0.0


func setup(index: int, config: GameConfig) -> void:
	_color = PlayerStyle.color(index)
	_body_mat = _overlay_material()
	_ring_mat = _overlay_material()
	var capsule := CapsuleMesh.new()
	capsule.radius = config.fighter_radius
	capsule.height = config.fighter_height
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.material_override = _body_mat
	body.position.y = config.fighter_height * 0.5
	add_child(body)
	var torus := TorusMesh.new()
	torus.inner_radius = config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = config.fighter_radius * RING_OUTER_RATIO
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.scale = Vector3(1.0, RING_FLATTEN, 1.0)
	ring.position.y = RING_LIFT
	add_child(ring)
	set_amount(0.0)


## Fog strength 0..1: 0 hides the silhouette.
func set_amount(amount: float) -> void:
	_amount = clampf(amount, 0.0, 1.0)
	visible = _amount > 0.001
	var body := _color
	body.a = BODY_ALPHA * _amount
	_body_mat.albedo_color = body
	var ring := _color
	ring.a = RING_ALPHA * _amount
	_ring_mat.albedo_color = ring


func amount() -> float:
	return _amount


func draws_over_fog() -> bool:
	return _body_mat.no_depth_test and _body_mat.disable_fog and _ring_mat.no_depth_test


static func _overlay_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.disable_fog = true
	m.render_priority = RENDER_PRIORITY
	return m
