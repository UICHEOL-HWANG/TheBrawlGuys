class_name BananaModel
extends ItemModel
## Banana peel (design.md DS-VIS-05, PRD-ITEM-07): a curved petal-yellow banana from a few short
## segments along an arc with bark-brown tips. Laid as a trap (view "trap") it shows splayed peel
## flaps flat on the ground instead, so a live trap reads differently from a pickup.

const ARC_RADIUS := 0.42
const ARC_SPAN := 1.6
const SEGMENTS := 4
const BODY_RADIUS := 0.075
const TIP_RADIUS := 0.04
const FLAP_COUNT := 3
const FLAP := Vector3(0.1, 0.03, 0.26)
## In the palm, like RockModel.HOLD.
const HOLD := Transform3D(Vector3(0, 0.85, 0), Vector3(-0.85, 0, 0), Vector3(0, 0, 0.85), Vector3(0.12, 0, 0.17))

var _whole: Node3D
var _peel: Node3D


func show_state(view: Dictionary, _tick: int) -> void:
	var trap := bool(view.get("trap", false))
	_whole.visible = not trap
	_peel.visible = trap


func is_showing_trap() -> bool:
	return _peel.visible


func hold_transform() -> Transform3D:
	return HOLD


func _build() -> void:
	_whole = Node3D.new()
	add_child(_whole)
	_peel = Node3D.new()
	add_child(_peel)
	_peel.visible = false
	var step := ARC_SPAN / SEGMENTS
	var seg_len := ARC_RADIUS * step * 1.15
	for i: int in SEGMENTS:
		var a := -ARC_SPAN * 0.5 + step * (i + 0.5)
		var at := Vector3(sin(a) * ARC_RADIUS, BODY_RADIUS + (1.0 - cos(a)) * ARC_RADIUS, 0)
		var r := BODY_RADIUS if i > 0 and i < SEGMENTS - 1 else BODY_RADIUS * 0.85
		_part(ItemParts.cylinder(r, r, seg_len), DS.PETAL_YELLOW, ItemParts.at(at, Vector3(0, 0, a - PI * 0.5)), _whole)  # axis along the arc tangent
	for side: float in [-1.0, 1.0]:
		var a := side * ARC_SPAN * 0.5
		var tip := Vector3(sin(a) * ARC_RADIUS, BODY_RADIUS + (1.0 - cos(a)) * ARC_RADIUS, 0)
		_part(ItemParts.sphere(TIP_RADIUS), DS.BARK, ItemParts.at(tip), _whole)
	for k: int in FLAP_COUNT:
		var turn := TAU * k / FLAP_COUNT
		var out := Vector3(sin(turn), 0, cos(turn)) * FLAP.z * 0.55
		_part(ItemParts.sphere(1.0), DS.PETAL_YELLOW, ItemParts.at(out + Vector3.UP * FLAP.y, Vector3(0, turn, 0), FLAP), _peel)
	_part(ItemParts.sphere(TIP_RADIUS * 1.4), DS.BARK, ItemParts.at(Vector3.UP * FLAP.y * 2.0), _peel)
