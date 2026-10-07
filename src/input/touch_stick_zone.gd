class_name TouchStickZone
extends RefCounted
## TouchInput's floating stick: its zone (left 40% x bottom 70% of the safe area), the finger
## steering it, the TouchStickModel that LocalInput reads and the TouchStick view.

const WIDTH := 0.4
const TOP := 0.3

var model: TouchStickModel
var finger: int = TouchFingers.NONE
var _view: TouchStick


func _init(p_model: TouchStickModel, view: TouchStick) -> void:
	model = p_model
	_view = view


## The middle of the zone (tests and captures press here).
static func point(safe: Rect2) -> Vector2:
	return Vector2(safe.position.x + safe.size.x * WIDTH * 0.5,
			safe.position.y + safe.size.y * (TOP + 1.0) * 0.5)


static func contains(safe: Rect2, pos: Vector2) -> bool:
	return pos.x <= safe.position.x + safe.size.x * WIDTH \
			and pos.y >= safe.position.y + safe.size.y * TOP


func is_free() -> bool:
	return finger == TouchFingers.NONE


func begin(index: int, pos: Vector2) -> void:
	finger = index
	model.begin(pos)
	_refresh()


func drag(index: int, pos: Vector2) -> void:
	if index == finger:
		model.move(pos)
		_refresh()


func end(index: int) -> void:
	if index == finger:
		finger = TouchFingers.NONE
		model.end()
		_view.hide_stick()


func _refresh() -> void:
	_view.show_stick(model.center(), model.knob(), model.radius)
