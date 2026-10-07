class_name PlankView
extends GimmickView
## Log bridge side plank (platform; design.md DS-VIS-04 "부서질 발판 = 균열이 단계적으로 커짐"):
## draws its own floor deck. Hits taken on it show a first crack; once the break warning starts
## the cracks grow through MAX_STAGE and the deck trembles harder; at the break it drops into the
## water and is gone; when the sim restores it, it bobs back up into place. IcePatchView reuses
## all of it with an ice surface.

const MAX_STAGE := 3
## Crack streaks per stage: [x along the plank, z across, yaw].
const CRACKS: Array[Vector3] = [Vector3(-0.8, 0.1, 0.5), Vector3(1.4, -0.2, -0.7), Vector3(0.2, 0.25, 1.2),
		Vector3(-2.0, -0.2, -0.4), Vector3(2.3, 0.15, 0.9), Vector3(-0.3, -0.3, -1.1)]
const CRACK_SIZE := Vector3(0.9, 0.03, 0.07)
const CRACK_LIFT := 0.012
const SHAKE_HZ := 22.0
const SHAKE_PER_STAGE := 0.025
const FALL_TIME := 0.7
const FALL_DEPTH := 3.0
const FALL_TILT := 0.5
const RISE_TIME := 0.45
const RISE_FROM := 1.2

var _floor_index: int = -1
var _deck: Node3D
var _cracks: Array[MeshInstance3D] = []
var _stage: int = 0
var _broken: bool = false
var _tween: Tween


## 0 intact .. MAX_STAGE about to break (plank view values, config warn time and hit budget).
static func crack_stage(view: Dictionary, warn_ticks: int, hits_to_break: int) -> int:
	if bool(view.get("broken", false)):
		return MAX_STAGE
	if bool(view.get("cracking", false)):
		var left := float(view.get("ticks_left", 0)) / float(maxi(warn_ticks, 1))
		return clampi(1 + floori((1.0 - left) * MAX_STAGE), 1, MAX_STAGE)
	var hits := int(view.get("hits", 0))
	if hits <= 0:
		return 0
	return clampi(ceili(float(hits) / float(maxi(hits_to_break, 1)) * (MAX_STAGE - 1)), 1, MAX_STAGE - 1)


func owned_floor() -> int:
	return _floor_index


func stage() -> int:
	return _stage


func deck_visible() -> bool:
	return _deck.visible


func _build(view: Dictionary) -> void:
	_floor_index = int(view.get("floor", -1))
	var area: Dictionary = view["area"]
	rotation.y = float(area.get("yaw", 0.0))
	_deck = Node3D.new()
	add_child(_deck)
	var size := (area["half"] as Vector2) * 2.0
	_build_surface(_deck, size)
	var mat := ToonMaterials.toon(_crack_color())
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = CRACK_SIZE
	for c: Vector3 in _crack_layout(size):
		var mi := _mesh(crack_mesh, mat, Vector3(c.x, _surface_lift() + CRACK_LIFT, c.y), _deck)
		mi.rotation.y = c.z
		mi.visible = false
		_cracks.append(mi)


## The walkable surface drawn into the deck node (size = x, z). Subclasses swap the look.
func _build_surface(deck: Node3D, size: Vector2) -> void:
	FloorMesh.deck(deck, size, _theme)


## Height of the drawn top above the sim floor top (cracks sit on it).
func _surface_lift() -> float:
	return 0.0


func _crack_color() -> Color:
	return DS.CANOPY_DEEP


## Crack streaks as [x, z, yaw] on the surface; every MAX_STAGE-th share shows per stage.
func _crack_layout(_size: Vector2) -> Array[Vector3]:
	return CRACKS


func _follow(view: Dictionary, _delta: float) -> void:
	var warn := SimTime.to_ticks(_config.platform_warn_time)
	_stage = crack_stage(view, warn, _config.platform_hits_to_break)
	var per_stage := _cracks.size() / MAX_STAGE
	for i: int in _cracks.size():
		_cracks[i].visible = i < _stage * per_stage
	var broken := bool(view.get("broken", false))
	if broken != _broken:
		_broken = broken
		if broken:
			_fall()
		else:
			_rise()
	if not _is_animating():
		var shaking := bool(view.get("cracking", false))
		_deck.position.x = sin(_time * TAU * SHAKE_HZ) * SHAKE_PER_STAGE * _stage if shaking else 0.0


func _is_animating() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _fall() -> void:
	_kill_tween()
	if not is_inside_tree():
		_deck.visible = false
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_deck, "position:y", -FALL_DEPTH, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_deck, "rotation:z", FALL_TILT, FALL_TIME)
	_tween.chain().tween_callback(func() -> void: _deck.visible = false)


func _rise() -> void:
	_kill_tween()
	_deck.visible = true
	_deck.rotation = Vector3.ZERO
	if not is_inside_tree():
		_deck.position = Vector3.ZERO
		return
	_deck.position = Vector3(0, -RISE_FROM, 0)
	_tween = create_tween()
	_tween.tween_property(_deck, "position:y", 0.0, RISE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
