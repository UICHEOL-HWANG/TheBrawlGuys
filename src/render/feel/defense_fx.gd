class_name DefenseFx
extends Node3D
## Defense VFX for one fighter (combat-depth A, design.md DS-VFX-10~13), a child of its
## FighterView. While the view says is_dodging the character turns see-through (instance
## transparency also fades its outline pass) and leaves pooled afterimages (DodgeGhosts); the guard bubble shrinks with guard_hp_ratio and flashes GUARD_BUBBLE_LOW when
## under LOW_RATIO; guard_broken circles DizzyStars over the head; perfect_flash() replays the
## PerfectRing. Reads view values only (render side, never touches the sim).

const FADED_TRANSPARENCY := 0.55
const LOW_RATIO := 0.3
const FLASH_HZ := 6.0
## Bubble radius share at an empty meter (full meter = the FighterView radius).
const MIN_BUBBLE := 0.45
const RESIZE_EPSILON := 0.005

var _view: FighterView
var _bubble_base: float = 0.0
var _normal_bubble: Material
var _low_bubble: Material
var _ghosts: DodgeGhosts
var _stars: DizzyStars
var _ring: PerfectRing
var _time: float = 0.0
var _faded: bool = false


func setup(index: int, config: GameConfig, view: FighterView) -> void:
	_view = view
	_bubble_base = (view.bubble().mesh as SphereMesh).radius
	_normal_bubble = view.bubble().material_override
	_low_bubble = ToonMaterials.translucent(DS.GUARD_BUBBLE_LOW)
	_ghosts = DodgeGhosts.new()
	add_child(_ghosts)
	_ghosts.setup(PlayerStyle.color(index), config)
	_stars = DizzyStars.new()
	add_child(_stars)
	_stars.setup(config)
	_ring = PerfectRing.new()
	add_child(_ring)
	_ring.setup(config)


## Every frame with the fighter's latest view.
func apply(curr: Dictionary, delta: float) -> void:
	_time += delta
	var dodging := bool(curr.get("is_dodging", false))
	_set_faded(dodging)
	_ghosts.advance(dodging, global_position, delta)
	_apply_bubble(float(curr.get("guard_hp_ratio", 1.0)))
	_stars.advance(bool(curr.get("guard_broken", false)), _time)
	_ring.advance(delta)


## A perfect guard: the bright ring bursts out around the fighter.
func perfect_flash() -> void:
	_ring.play()


func faded() -> bool:
	return _faded


func ghost_count() -> int:
	return _ghosts.active_count()


func stars_visible() -> bool:
	return _stars.visible


func ring_visible() -> bool:
	return _ring.visible


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
