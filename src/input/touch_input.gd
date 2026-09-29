class_name TouchInput
extends CanvasLayer
## Phase 1 touch controls (PRD §3.3, design.md DS-LAY-01): floating stick on the left 40% x
## bottom 70% of the screen, jump + attack buttons bottom-right. Jump fires on press; attack
## fires a light attack on release (tap) — holds become heavy in Phase 2. Finger index >= 3
## (four-finger tap) belongs to the debug panel. Debug builds without a touchscreen also accept
## the left mouse button as finger 0 for desktop testing.

const TOUCH_STICK_SCENE := preload("res://src/ui/components/touch_stick/touch_stick.tscn")
const TOUCH_BUTTON_SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")
const LAYER := 10
const STICK_ZONE_WIDTH := 0.4
const STICK_ZONE_TOP := 0.3
const MAX_FINGERS := 3
const MOUSE_FINGER := 0
const NO_FINGER := -1

var _local: LocalInput
var _model: TouchStickModel
var _stick: TouchStick
var _jump: TouchButton
var _attack: TouchButton
var _stick_finger: int = NO_FINGER
var _jump_finger: int = NO_FINGER
var _attack_finger: int = NO_FINGER


func setup(local: LocalInput, config: GameConfig) -> void:
	_local = local
	layer = LAYER
	_model = TouchStickModel.new(config.touch_stick_radius, config.touch_stick_deadzone)
	local.touch_stick = _model
	_stick = TOUCH_STICK_SCENE.instantiate() as TouchStick
	add_child(_stick)
	_attack = _make_button("공격", config.touch_attack_diameter)
	_jump = _make_button("점프", config.touch_jump_diameter)
	visible = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func attack_center() -> Vector2:
	return _attack.get_global_rect().get_center()


func jump_center() -> Vector2:
	return _jump.get_global_rect().get_center()


func stick_zone_point() -> Vector2:
	var vp := _viewport_size()
	return Vector2(vp.x * STICK_ZONE_WIDTH * 0.5, vp.y * (STICK_ZONE_TOP + 1.0) * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index < MAX_FINGERS:
			_finger(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
	elif _mouse_as_finger() and event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_finger(MOUSE_FINGER, m.position, m.pressed)
	elif _mouse_as_finger() and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_FINGER, mm.position)


func _make_button(text: String, d: float) -> TouchButton:
	var b := TOUCH_BUTTON_SCENE.instantiate() as TouchButton
	b.label_text = text
	b.diameter = d
	add_child(b)
	return b


func _layout() -> void:
	var vp := _viewport_size()
	var a := _attack.diameter
	_attack.position = Vector2(vp.x - DS.S8 - a, vp.y - DS.S8 - a)
	_jump.position = _attack.position + Vector2(-_jump.diameter - DS.S6, a - _jump.diameter)


func _finger(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		_down(index, pos)
	else:
		_up(index)


func _down(index: int, pos: Vector2) -> void:
	visible = true
	if _attack_finger == NO_FINGER and _attack.contains(pos):
		_attack_finger = index
		_attack.set_state(TouchButton.State.PRESSED)
	elif _jump_finger == NO_FINGER and _jump.contains(pos):
		_jump_finger = index
		_jump.set_state(TouchButton.State.PRESSED)
		_local.press_jump()
	elif _stick_finger == NO_FINGER and _in_stick_zone(pos):
		_stick_finger = index
		_model.begin(pos)
		_refresh_stick()


func _up(index: int) -> void:
	if index == _attack_finger:
		_attack_finger = NO_FINGER
		_attack.set_state(TouchButton.State.IDLE)
		_local.press_light()
	if index == _jump_finger:
		_jump_finger = NO_FINGER
		_jump.set_state(TouchButton.State.IDLE)
	if index == _stick_finger:
		_stick_finger = NO_FINGER
		_model.end()
		_stick.hide_stick()


func _drag(index: int, pos: Vector2) -> void:
	if index == _stick_finger:
		_model.move(pos)
		_refresh_stick()


func _refresh_stick() -> void:
	_stick.show_stick(_model.center(), _model.knob(), _model.radius)


func _in_stick_zone(pos: Vector2) -> bool:
	var vp := _viewport_size()
	return pos.x <= vp.x * STICK_ZONE_WIDTH and pos.y >= vp.y * STICK_ZONE_TOP


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _mouse_as_finger() -> bool:
	return OS.is_debug_build() and not DisplayServer.is_touchscreen_available()
