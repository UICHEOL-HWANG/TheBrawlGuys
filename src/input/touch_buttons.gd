class_name TouchButtons
extends RefCounted
## TouchInput's four on-screen buttons (design.md DS-LAY-01): built in TouchLayout.BUTTONS order,
## placed by config.touch_layout inside the safe area, and which finger holds each one. A button
## nobody touches rests disabled, highlighted (grab, with a target in reach) or idle.

const TOUCH_BUTTON_SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")
const NO_FINGER := TouchFingers.NONE
const LABELS := {"attack": "공격", "jump": "점프", "guard": "가드", "grab": "잡기"}
const ICONS := {
	"attack": TouchIcons.Icon.ATTACK, "jump": TouchIcons.Icon.JUMP,
	"guard": TouchIcons.Icon.GUARD, "grab": TouchIcons.Icon.GRAB,
}

var enabled: bool = true
var grab_highlight: bool = false
var _buttons: Dictionary = {}
var _owner: Dictionary = {}


func _init(parent: Node) -> void:
	for name: String in TouchLayout.BUTTONS:
		var b := TOUCH_BUTTON_SCENE.instantiate() as TouchButton
		b.label_text = LABELS[name]
		b.icon = ICONS[name]
		b.dim_when_idle = name == "grab"
		parent.add_child(b)
		_buttons[name] = b
		_owner[name] = NO_FINGER


func all() -> Dictionary:
	return _buttons


func center(name: String) -> Vector2:
	return (_buttons[name] as TouchButton).get_global_rect().get_center()


func is_held(name: String) -> bool:
	return _owner[name] != NO_FINGER


func button(name: String) -> TouchButton:
	return _buttons[name]


## The free button under pos, now held by finger ("" when there is none).
func press_at(pos: Vector2, finger: int) -> String:
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		if _owner[name] == NO_FINGER and b.contains(pos):
			_owner[name] = finger
			b.set_state(TouchButton.State.PRESSED)
			return name
	return ""


## Lets go of the buttons finger holds and returns their names.
func release_finger(finger: int) -> Array[String]:
	var released: Array[String] = []
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] == finger:
			_owner[name] = NO_FINGER
			refresh_idle(name)
			released.append(name)
	return released


## Fingers holding a button, in button order.
func held_fingers() -> Array[int]:
	var fingers: Array[int] = []
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] != NO_FINGER:
			fingers.append(_owner[name])
	return fingers


## Resting look of a button nobody is touching: disabled, highlighted (grab) or idle.
func refresh_idle(name: String) -> void:
	if _owner[name] != NO_FINGER:
		return
	var b: TouchButton = _buttons[name]
	if not enabled:
		b.set_state(TouchButton.State.DISABLED)
	elif name == "grab" and grab_highlight:
		b.set_state(TouchButton.State.HIGHLIGHT)
	else:
		b.set_state(TouchButton.State.IDLE)


func refresh_all() -> void:
	for name: String in TouchLayout.BUTTONS:
		refresh_idle(name)


func layout(config: GameConfig, safe: Rect2) -> void:
	var sizes := {
		"attack": config.touch_attack_diameter, "jump": config.touch_jump_diameter,
		"guard": config.touch_side_diameter, "grab": config.touch_side_diameter,
	}
	var centers := TouchLayout.centers(config.touch_layout, safe, sizes, DS.S5, DS.S8)
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		b.set_diameter(sizes[name])
		b.position = (centers[name] as Vector2) - Vector2(b.diameter, b.diameter) * 0.5
