class_name DefenseFx
extends Node3D
## Defense VFX for one fighter (combat-depth A, design.md DS-VFX-10~13), a child of its
## FighterView. While the view says is_dodging the character turns see-through and leaves fading
## afterimages; the guard bubble shrinks with guard_hp_ratio and flashes GUARD_BUBBLE_LOW when
## under LOW_RATIO; guard_broken circles dizzy stars over the head; perfect_flash() pops a
## bright ring. Reads view values only (render side, never touches the sim).

const GHOST_INTERVAL := 0.05
const GHOST_ALPHA := 0.35
const FADED_TRANSPARENCY := 0.55
const LOW_RATIO := 0.3
const FLASH_HZ := 6.0
## Bubble radius share at an empty meter (full meter = the FighterView radius).
const MIN_BUBBLE := 0.45
const RESIZE_EPSILON := 0.005
const STAR_COUNT := 3
const STAR_RADIUS := 0.09
const STAR_ORBIT := 0.35
const STAR_LIFT := 0.25
const STAR_SPIN_HZ := 1.2
const RING_INNER_RATIO := 1.1
const RING_OUTER_RATIO := 1.35
const RING_START_SCALE := 0.6
const RING_END_SCALE := 2.4

var _config: GameConfig
var _view: FighterView
var _color: Color
var _bubble_base: float = 0.0
var _normal_bubble: Material
var _low_bubble: Material
var _ghosts: Node3D
var _stars: Node3D
var _ghost_clock: float = 0.0
var _time: float = 0.0
var _faded: bool = false


func setup(index: int, config: GameConfig, view: FighterView) -> void:
	_config = config
	_view = view
	_color = PlayerStyle.color(index)
	_bubble_base = (view.bubble().mesh as SphereMesh).radius
	_normal_bubble = view.bubble().material_override
	_low_bubble = ToonMaterials.translucent(DS.GUARD_BUBBLE_LOW)
	_ghosts = Node3D.new()
	_ghosts.top_level = true  # afterimages stay where they were left
	add_child(_ghosts)
	_build_stars()


## Every frame with the fighter's latest view.
func apply(curr: Dictionary, delta: float) -> void:
	_time += delta
	_apply_dodge(bool(curr.get("is_dodging", false)), delta)
	_apply_bubble(float(curr.get("guard_hp_ratio", 1.0)))
	_stars.visible = bool(curr.get("guard_broken", false))
	if _stars.visible:
		_stars.rotation.y = _time * TAU * STAR_SPIN_HZ


## A perfect guard: a bright ring bursts out around the fighter.
func perfect_flash() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = _config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = _config.fighter_radius * RING_OUTER_RATIO
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	var mat := ToonMaterials.translucent(DS.GLOW).duplicate() as StandardMaterial3D
	ring.material_override = mat
	ring.position.y = _config.fighter_height * 0.5
	ring.scale = Vector3.ONE * RING_START_SCALE
	add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * RING_END_SCALE, DS.MOTION_SLOW).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, DS.MOTION_SLOW)
	tw.chain().tween_callback(ring.queue_free)


func faded() -> bool:
	return _faded


func ghost_count() -> int:
	return _ghosts.get_child_count()


func stars_visible() -> bool:
	return _stars.visible


func _apply_dodge(dodging: bool, delta: float) -> void:
	_set_faded(dodging)
	if not dodging:
		_ghost_clock = 0.0
		return
	_ghost_clock += delta
	if _ghost_clock >= GHOST_INTERVAL:
		_ghost_clock = 0.0
		_spawn_ghost()


## See-through character while intangible (per-instance transparency: shared materials untouched).
func _set_faded(on: bool) -> void:
	if on == _faded:
		return
	_faded = on
	var model := _view.model()
	if model == null:
		return
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = FADED_TRANSPARENCY if on else 0.0


func _spawn_ghost() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = _config.fighter_radius
	capsule.height = _config.fighter_height
	var tint := _color
	tint.a = GHOST_ALPHA
	var mat := ToonMaterials.translucent(tint).duplicate() as StandardMaterial3D
	var ghost := MeshInstance3D.new()
	ghost.mesh = capsule
	ghost.material_override = mat
	_ghosts.add_child(ghost)
	ghost.global_position = global_position + Vector3.UP * (_config.fighter_height * 0.5)
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, DS.MOTION_BASE)
	tw.tween_callback(ghost.queue_free)


## Bubble radius follows the meter; under LOW_RATIO it flashes the warning look.
func _apply_bubble(ratio: float) -> void:
	var bubble := _view.bubble()
	var mesh := bubble.mesh as SphereMesh
	var radius := _bubble_base * lerpf(MIN_BUBBLE, 1.0, clampf(ratio, 0.0, 1.0))
	if absf(mesh.radius - radius) > RESIZE_EPSILON:
		mesh.radius = radius
		mesh.height = radius * 2.0
	var flash := ratio < LOW_RATIO and fmod(_time * FLASH_HZ, 1.0) < 0.5
	bubble.material_override = _low_bubble if flash else _normal_bubble


func _build_stars() -> void:
	_stars = Node3D.new()
	_stars.position.y = _config.fighter_height + STAR_LIFT
	_stars.visible = false
	add_child(_stars)
	var sphere := SphereMesh.new()
	sphere.radius = STAR_RADIUS
	sphere.height = STAR_RADIUS * 2.0
	for i: int in STAR_COUNT:
		var star := MeshInstance3D.new()
		star.mesh = sphere
		star.material_override = ToonMaterials.toon(DS.PETAL_YELLOW, 0.8)
		var angle := TAU * float(i) / STAR_COUNT
		star.position = Vector3(cos(angle), 0.0, sin(angle)) * STAR_ORBIT
		_stars.add_child(star)
