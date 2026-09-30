class_name CharacterSelectInput
extends RefCounted
## Character select input routing (Phase 5 T9, PRD-LOCAL-01): which seat an event belongs to and
## what it does. Alone, every key and pad drives seat 0 (the arena select keys work too: arrows,
## Z / Enter / Space, X / Esc). With two humans the keyboard splits by InputBindings — P1 arrows ·
## light (Z) · heavy (X), P2 A D · F · G, plus Enter / Esc for P1 — and each pad drives the seat
## pad_seat(device) names (GamepadAssigner's owner; -1 = nobody). Pads: d-pad / left stick browse
## (StickNav latch per seat), A confirms, B cancels. Result {seat, cmd, step, device}.

const NONE := ""
const MOVE := "move"
const CONFIRM := "confirm"
const CANCEL := "cancel"
## A held or returning stick, or a repeating menu key: swallowed so it neither repeats nor
## drives GUI focus.
const HELD := "held"
const DEVICE_KEYBOARD := "keyboard"
const DEVICE_GAMEPAD := "gamepad"
const SOLO_CONFIRM: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const SOLO_CANCEL: Array[Key] = [KEY_X, KEY_ESCAPE]
const P1_EXTRA_CONFIRM: Array[Key] = [KEY_ENTER, KEY_KP_ENTER]
const P1_EXTRA_CANCEL: Array[Key] = [KEY_ESCAPE]

var _two: bool
var _pad_seat: Callable
## seat -> StickNav
var _sticks: Dictionary = {}


func _init(two_players: bool, pad_seat: Callable) -> void:
	_two = two_players
	_pad_seat = pad_seat
	InputBindings.apply()


func route(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed:
			return {}
		var r := _two_keys(key) if _two else _solo_key(key)
		if key.echo and not r.is_empty():
			r["cmd"] = HELD  # a held menu key: swallowed, never repeated nor left to GUI focus
		return r
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var seat := 0 if not _two else int(_pad_seat.call(event.device))
		return {} if seat < 0 else _pad(event, seat)
	return {}


## Forgets held sticks (the screen was away while they were released).
func reset_sticks() -> void:
	_sticks.clear()


func _solo_key(key: InputEventKey) -> Dictionary:
	var step := _step_keys(key, "p1")
	if step == 0:
		step = -1 if key.is_action_pressed("ui_left") else (1 if key.is_action_pressed("ui_right") else 0)
	if step != 0:
		return _out(0, MOVE, DEVICE_KEYBOARD, step)
	if SOLO_CONFIRM.has(_code(key)) or key.is_action_pressed("ui_accept"):
		return _out(0, CONFIRM, DEVICE_KEYBOARD)
	if SOLO_CANCEL.has(_code(key)) or key.is_action_pressed("ui_cancel"):
		return _out(0, CANCEL, DEVICE_KEYBOARD)
	return {}


func _two_keys(key: InputEventKey) -> Dictionary:
	for seat: int in InputBindings.PREFIXES.size():
		var prefix := InputBindings.PREFIXES[seat]
		var step := _step_keys(key, prefix)
		if step != 0:
			return _out(seat, MOVE, DEVICE_KEYBOARD, step)
		if key.is_action_pressed(InputBindings.action(prefix, "light")) \
				or (seat == 0 and P1_EXTRA_CONFIRM.has(_code(key))):
			return _out(seat, CONFIRM, DEVICE_KEYBOARD)
		if key.is_action_pressed(InputBindings.action(prefix, "heavy")) \
				or (seat == 0 and P1_EXTRA_CANCEL.has(_code(key))):
			return _out(seat, CANCEL, DEVICE_KEYBOARD)
	return {}


func _pad(event: InputEvent, seat: int) -> Dictionary:
	if event is InputEventJoypadMotion:
		var stick := _stick(seat)
		var motion := event as InputEventJoypadMotion
		var step := stick.step(motion)
		if step != 0:
			return _out(seat, MOVE, DEVICE_GAMEPAD, step)
		return _out(seat, HELD, DEVICE_GAMEPAD) if stick.owns(motion) else {}
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return {}
	match button.button_index:
		JOY_BUTTON_DPAD_LEFT:
			return _out(seat, MOVE, DEVICE_GAMEPAD, -1)
		JOY_BUTTON_DPAD_RIGHT:
			return _out(seat, MOVE, DEVICE_GAMEPAD, 1)
		JOY_BUTTON_A:
			return _out(seat, CONFIRM, DEVICE_GAMEPAD)
		JOY_BUTTON_B:
			return _out(seat, CANCEL, DEVICE_GAMEPAD)
	return {}


func _stick(seat: int) -> StickNav:
	if not _sticks.has(seat):
		_sticks[seat] = StickNav.new()
	return _sticks[seat] as StickNav


## -1 / +1 for the player's left / right keys (keyboard events of the actions only).
static func _step_keys(key: InputEventKey, prefix: String) -> int:
	if key.is_action_pressed(InputBindings.action(prefix, "left")):
		return -1
	if key.is_action_pressed(InputBindings.action(prefix, "right")):
		return 1
	return 0


static func _code(key: InputEventKey) -> Key:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode


static func _out(seat: int, cmd: String, device: String, step: int = 0) -> Dictionary:
	return {"seat": seat, "cmd": cmd, "step": step, "device": device}
