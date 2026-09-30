class_name SeatDevices
extends RefCounted
## Which device each human on a select screen uses (Phase 5 T9, DS-TOK-06, PRD-LOCAL-01): with
## two humans a GamepadAssigner hands out pads by the match rule (so the prompts match who will
## hold which pad in the match); alone every pad is P1's. A seat's prompts follow the device it
## last used, else the pad it holds, touch on touch screens (alone) or the keyboard.

var _pads: GamepadAssigner = null
## seat -> "keyboard" | "gamepad" | "touch"
var _used: Dictionary = {}
var _last_pad: int = GamepadAssigner.NO_DEVICE


func _init(human_count: int) -> void:
	if human_count > 1:
		var prefixes: Array[String] = []
		for i: int in mini(human_count, InputBindings.PREFIXES.size()):
			prefixes.append(InputBindings.PREFIXES[i])
		_pads = GamepadAssigner.new(prefixes)


## Follows pad connections while the screen shows (the match assigns pads itself later).
func attach() -> void:
	if _pads != null:
		_pads.attach()


func detach() -> void:
	if _pads != null:
		_pads.detach()


func assigner() -> GamepadAssigner:
	return _pads


## The seat a pad drives: its GamepadAssigner owner with two humans (-1 = nobody), else P1.
func pad_seat(device: int) -> int:
	return InputBindings.PREFIXES.find(_pads.player_for(device)) if _pads != null else 0


func note(seat: int, device: String, pad: int = GamepadAssigner.NO_DEVICE) -> void:
	_used[seat] = device
	if pad != GamepadAssigner.NO_DEVICE:
		_last_pad = pad


func device_of(seat: int) -> String:
	if _used.has(seat):
		return String(_used[seat])
	if pad_of(seat) != GamepadAssigner.NO_DEVICE:
		return SelectPrompts.DEVICE_GAMEPAD
	if _pads == null and DisplayProbe.touch_available():
		return SelectPrompts.DEVICE_TOUCH
	return SelectPrompts.DEVICE_KEYBOARD


func pad_of(seat: int) -> int:
	if _pads != null:
		return _pads.device_for(InputBindings.PREFIXES[seat])
	if _last_pad != GamepadAssigner.NO_DEVICE:
		return _last_pad
	var connected := Input.get_connected_joypads()
	return int(connected[0]) if not connected.is_empty() else GamepadAssigner.NO_DEVICE


func prompts(seat: int) -> Array[Dictionary]:
	var pad := pad_of(seat)
	var family := SelectPrompts.pad_family(Input.get_joy_name(pad)) if pad >= 0 else SelectPrompts.FAMILY_XBOX
	return SelectPrompts.for_player(InputBindings.PREFIXES[seat], device_of(seat), family)


## A mouse click or a tap.
static func pointer_device() -> String:
	return SelectPrompts.DEVICE_TOUCH if DisplayProbe.touch_available() else SelectPrompts.DEVICE_KEYBOARD
