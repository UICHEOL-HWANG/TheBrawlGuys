class_name TouchInput
extends CanvasLayer
## Touch controls (PRD §3.3, design.md DS-LAY-01): floating stick on the left 40% x bottom 70% of
## the safe area (TouchStickZone), four buttons bottom-right in the layout chosen by
## config.touch_layout (E9, TouchButtons). What each button sends lives in TouchActions. Canceled touches and focus loss
## release everything without firing a tap. Raw touch ids map to fingers 0..2 on press
## (TouchFingers); a fourth finger belongs to the debug panel. Debug builds without a touchscreen
## accept the left mouse button as finger 0 for desktop testing.

signal button_pressed(name: String)

const TOUCH_STICK_SCENE := preload("res://src/ui/components/touch_stick/touch_stick.tscn")
const LAYER := 10
const MAX_FINGERS := 3
const MOUSE_FINGER := 0
const NO_FINGER := TouchFingers.NONE

## Test clock: when >= 0 it replaces the real time in seconds.
var time_override: float = -1.0
var _local: LocalInput
var _config: GameConfig
var _actions: TouchActions
var _stick: TouchStickZone
var _buttons: TouchButtons
var _fingers := TouchFingers.new(MAX_FINGERS)
## Hidden while the result is up (set_suppressed); a touch does not bring them back meanwhile.
var _suppressed: bool = false
var _shown_before: bool = false


func setup(local: LocalInput, config: GameConfig) -> void:
	_local = local
	_config = config
	layer = LAYER
	var model := TouchStickModel.new(config.touch_stick_radius, config.touch_stick_deadzone)
	_actions = TouchActions.new(local, config.touch_hold_threshold)
	local.touch_stick = model
	var view := TOUCH_STICK_SCENE.instantiate() as TouchStick
	add_child(view)
	_stick = TouchStickZone.new(model, view)
	_buttons = TouchButtons.new(self)
	visible = DisplayProbe.touch_available()
	get_viewport().size_changed.connect(_layout)
	config.changed.connect(_layout)
	_layout()


func buttons() -> Dictionary:
	return _buttons.all()


func button_center(name: String) -> Vector2:
	return _buttons.center(name)


func attack_center() -> Vector2:
	return button_center("attack")


func jump_center() -> Vector2:
	return button_center("jump")


func stick_zone_point() -> Vector2:
	return TouchStickZone.point(SafeArea.rect(get_viewport()))


## Seconds the attack button has been charging (0 when not holding a heavy).
func attack_charge_time() -> float:
	return _actions.charge_time(_now())


func set_grab_highlight(on: bool) -> void:
	if on == _buttons.grab_highlight:
		return
	_buttons.grab_highlight = on
	_buttons.refresh_idle("grab")


func set_enabled(on: bool) -> void:
	if on == _buttons.enabled:
		return
	_buttons.enabled = on
	if not on:
		_release_all()
	_buttons.refresh_all()


## Rings the buttons the tutorial asks for now (TouchLayout names; [] clears); still = reduce
## motion.
func set_targets(names: Array, still: bool = false) -> void:
	for name: String in TouchLayout.BUTTONS:
		_buttons.button(name).set_target(names.has(name), still)


## Hides (and releases) the controls while the result is up; false restores how they were.
func set_suppressed(on: bool) -> void:
	if on == _suppressed:
		return
	_suppressed = on
	if on:
		_shown_before = visible
		_release_all()
	visible = _shown_before and not on


func _process(_delta: float) -> void:
	if _actions == null or not _buttons.is_held("attack"):
		return
	var now := _now()
	if _actions.hold_attack(now):
		var attack := _buttons.button("attack")
		attack.set_state(TouchButton.State.CHARGING)
		attack.set_charge(_actions.charge_time(now) / maxf(_config.heavy_charge_max_time, 0.01))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var finger := _fingers.claim(t.index)
			if finger != NO_FINGER:
				_down(finger, t.position)
		elif _fingers.of(t.index) != NO_FINGER:
			_up(_fingers.of(t.index), t.canceled)
			_fingers.release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _fingers.of(d.index) != NO_FINGER:
			_stick.drag(_fingers.of(d.index), d.position)
	elif _mouse_as_finger():
		_mouse_input(event)


## Debug builds without a touchscreen: the left mouse button is finger 0.
func _mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_down(MOUSE_FINGER, m.position)
			else:
				_up(MOUSE_FINGER, false)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_stick.drag(MOUSE_FINGER, mm.position)


func _layout() -> void:
	if _config != null:
		_buttons.layout(_config, SafeArea.rect(get_viewport()))


func _down(index: int, pos: Vector2) -> void:
	if _suppressed:
		return
	visible = true
	if not _buttons.enabled:
		return
	var name := _buttons.press_at(pos, index)
	if not name.is_empty():
		button_pressed.emit(name)
		_actions.press(name, _now())
		return
	if _stick.is_free() and TouchStickZone.contains(SafeArea.rect(get_viewport()), pos):
		_stick.begin(index, pos)


func _up(index: int, canceled: bool) -> void:
	for name: String in _buttons.release_finger(index):
		_actions.release(name, _now(), canceled)
	_stick.end(index)


func _release_all() -> void:
	var fingers := _buttons.held_fingers()
	if not _stick.is_free():
		fingers.append(_stick.finger)
	for index: int in fingers:
		_up(index, true)
	_fingers.clear()
	# Latches keep a released press for one tick so quick taps survive; after focus loss nothing
	# may still fire, so drop them.
	_local.reset()


func _now() -> float:
	return time_override if time_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func _mouse_as_finger() -> bool:
	return OS.is_debug_build() and not DisplayProbe.touch_available()
