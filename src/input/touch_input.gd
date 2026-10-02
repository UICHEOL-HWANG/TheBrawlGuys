class_name TouchInput
extends CanvasLayer
## Touch controls (PRD §3.3, design.md DS-LAY-01): floating stick on the left 40% x bottom 70% of
## the safe area, four buttons bottom-right in the layout chosen by config.touch_layout (E9).
## Attack: tap = light on release, hold = heavy charge (AttackButtonModel). Jump and grab fire on
## press; guard holds while touched. Canceled touches and focus loss release everything without
## firing a tap. Raw touch ids map to fingers 0..2 on press (iOS Safari reports big arbitrary
## Touch.identifier values, Android 0, 1, 2); a fourth finger belongs to the debug panel. Debug builds
## without a touchscreen accept the left mouse button as finger 0 for desktop testing.

signal button_pressed(name: String)

const TOUCH_STICK_SCENE := preload("res://src/ui/components/touch_stick/touch_stick.tscn")
const TOUCH_BUTTON_SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")
const LAYER := 10
const STICK_ZONE_WIDTH := 0.4
const STICK_ZONE_TOP := 0.3
const MAX_FINGERS := 3
const MOUSE_FINGER := 0
const NO_FINGER := -1
const LABELS := {"attack": "공격", "jump": "점프", "guard": "가드", "grab": "잡기"}
const ICONS := {
	"attack": TouchIcons.Icon.ATTACK, "jump": TouchIcons.Icon.JUMP,
	"guard": TouchIcons.Icon.GUARD, "grab": TouchIcons.Icon.GRAB,
}

## Test clock: when >= 0 it replaces the real time in seconds.
var time_override: float = -1.0
var _local: LocalInput
var _config: GameConfig
var _model: TouchStickModel
var _attack_model: AttackButtonModel
var _stick: TouchStick
var _buttons: Dictionary = {}
var _owner: Dictionary = {}
var _stick_finger: int = NO_FINGER
var _heavy_sent: bool = false
var _enabled: bool = true
## Hidden while the result is up (set_suppressed); a touch does not bring them back meanwhile.
var _suppressed: bool = false
var _shown_before: bool = false
var _grab_highlight: bool = false
## Raw touch id (InputEvent index) -> finger 0..MAX_FINGERS-1, from press to release.
var _fingers: Dictionary = {}


func setup(local: LocalInput, config: GameConfig) -> void:
	_local = local
	_config = config
	layer = LAYER
	_model = TouchStickModel.new(config.touch_stick_radius, config.touch_stick_deadzone)
	_attack_model = AttackButtonModel.new(config.touch_hold_threshold)
	local.touch_stick = _model
	_stick = TOUCH_STICK_SCENE.instantiate() as TouchStick
	add_child(_stick)
	for name: String in TouchLayout.BUTTONS:
		var b := TOUCH_BUTTON_SCENE.instantiate() as TouchButton
		b.label_text = LABELS[name]
		b.icon = ICONS[name]
		b.dim_when_idle = name == "grab"
		add_child(b)
		_buttons[name] = b
		_owner[name] = NO_FINGER
	visible = DisplayProbe.touch_available()
	get_viewport().size_changed.connect(_layout)
	config.changed.connect(_layout)
	_layout()


func buttons() -> Dictionary:
	return _buttons


func button_center(name: String) -> Vector2:
	return (_buttons[name] as TouchButton).get_global_rect().get_center()


func attack_center() -> Vector2:
	return button_center("attack")


func jump_center() -> Vector2:
	return button_center("jump")


func stick_zone_point() -> Vector2:
	var safe := SafeArea.rect(get_viewport())
	return Vector2(safe.position.x + safe.size.x * STICK_ZONE_WIDTH * 0.5,
			safe.position.y + safe.size.y * (STICK_ZONE_TOP + 1.0) * 0.5)


## Seconds the attack button has been charging (0 when not holding a heavy).
func attack_charge_time() -> float:
	return _attack_model.charge_time(_now())


func set_grab_highlight(on: bool) -> void:
	if on == _grab_highlight:
		return
	_grab_highlight = on
	_refresh_idle("grab")


func set_enabled(on: bool) -> void:
	if on == _enabled:
		return
	_enabled = on
	if not on:
		_release_all()
	for name: String in TouchLayout.BUTTONS:
		_refresh_idle(name)


## Hides (and releases) the controls while the result is up; false restores how they were.
func set_suppressed(on: bool) -> void:
	if on == _suppressed:
		return
	_suppressed = on
	if on:
		_shown_before = visible
		_release_all()
	visible = _shown_before and not on


## Resting look of a button nobody is touching: disabled, highlighted (grab) or idle.
func _refresh_idle(name: String) -> void:
	if _owner[name] != NO_FINGER:
		return
	var b: TouchButton = _buttons[name]
	if not _enabled:
		b.set_state(TouchButton.State.DISABLED)
	elif name == "grab" and _grab_highlight:
		b.set_state(TouchButton.State.HIGHLIGHT)
	else:
		b.set_state(TouchButton.State.IDLE)


func _process(_delta: float) -> void:
	if _attack_model == null or _owner["attack"] == NO_FINGER:
		return
	var now := _now()
	if _attack_model.holding_heavy(now):
		if not _heavy_sent:
			_heavy_sent = true
			_local.set_touch_heavy(true)
		var attack: TouchButton = _buttons["attack"]
		attack.set_state(TouchButton.State.CHARGING)
		attack.set_charge(_attack_model.charge_time(now) / maxf(_config.heavy_charge_max_time, 0.01))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var finger := _claim_finger(t.index)
			if finger != NO_FINGER:
				_down(finger, t.position)
		elif _fingers.has(t.index):
			_up(int(_fingers[t.index]), t.canceled)
			_fingers.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _fingers.has(d.index):
			_drag(int(_fingers[d.index]), d.position)
	elif _mouse_as_finger() and event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_down(MOUSE_FINGER, m.position)
			else:
				_up(MOUSE_FINGER, false)
	elif _mouse_as_finger() and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(MOUSE_FINGER, mm.position)


## The finger a raw touch id presses with: its own if already down, else the lowest free one
## (NO_FINGER when all are taken).
func _claim_finger(id: int) -> int:
	if _fingers.has(id):
		return int(_fingers[id])
	for f: int in MAX_FINGERS:
		if not _fingers.values().has(f):
			_fingers[id] = f
			return f
	return NO_FINGER


func _layout() -> void:
	if _config == null:
		return
	var sizes := {
		"attack": _config.touch_attack_diameter, "jump": _config.touch_jump_diameter,
		"guard": _config.touch_side_diameter, "grab": _config.touch_side_diameter,
	}
	var centers := TouchLayout.centers(_config.touch_layout, SafeArea.rect(get_viewport()), sizes, DS.S5, DS.S8)
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		b.set_diameter(sizes[name])
		b.position = (centers[name] as Vector2) - Vector2(b.diameter, b.diameter) * 0.5


func _down(index: int, pos: Vector2) -> void:
	if _suppressed:
		return
	visible = true
	if not _enabled:
		return
	for name: String in TouchLayout.BUTTONS:
		var b: TouchButton = _buttons[name]
		if _owner[name] == NO_FINGER and b.contains(pos):
			_owner[name] = index
			b.set_state(TouchButton.State.PRESSED)
			_button_down(name)
			return
	if _stick_finger == NO_FINGER and _in_stick_zone(pos):
		_stick_finger = index
		_model.begin(pos)
		_refresh_stick()


func _up(index: int, canceled: bool) -> void:
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] == index:
			_owner[name] = NO_FINGER
			_refresh_idle(name)
			_button_up(name, canceled)
	if index == _stick_finger:
		_stick_finger = NO_FINGER
		_model.end()
		_stick.hide_stick()


func _release_all() -> void:
	var fingers: Array[int] = []
	for name: String in TouchLayout.BUTTONS:
		if _owner[name] != NO_FINGER:
			fingers.append(_owner[name])
	if _stick_finger != NO_FINGER:
		fingers.append(_stick_finger)
	for index: int in fingers:
		_up(index, true)
	_fingers.clear()
	# Latches keep a released press for one tick so quick taps survive; after focus loss nothing
	# may still fire, so drop them.
	_local.reset()


func _button_down(name: String) -> void:
	button_pressed.emit(name)
	match name:
		"attack":
			_attack_model.press(_now())
		"jump":
			_local.press_jump()
		"guard":
			_local.set_touch_guard(true)
		"grab":
			_local.press_grab()


func _button_up(name: String, canceled: bool) -> void:
	match name:
		"attack":
			var result := _attack_model.release(_now(), canceled)
			if result == AttackButtonModel.Result.LIGHT:
				_local.press_light()
			elif result == AttackButtonModel.Result.HEAVY_RELEASE:
				_local.set_touch_heavy(true)  # a no-op when _process already sent it
				_local.set_touch_heavy(false)
			_heavy_sent = false
		"guard":
			_local.set_touch_guard(false)


func _drag(index: int, pos: Vector2) -> void:
	if index == _stick_finger:
		_model.move(pos)
		_refresh_stick()


func _refresh_stick() -> void:
	_stick.show_stick(_model.center(), _model.knob(), _model.radius)


func _in_stick_zone(pos: Vector2) -> bool:
	var safe := SafeArea.rect(get_viewport())
	return pos.x <= safe.position.x + safe.size.x * STICK_ZONE_WIDTH \
			and pos.y >= safe.position.y + safe.size.y * STICK_ZONE_TOP


func _now() -> float:
	return time_override if time_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func _mouse_as_finger() -> bool:
	return OS.is_debug_build() and not DisplayProbe.touch_available()
