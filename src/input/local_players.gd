class_name LocalPlayers
extends RefCounted
## The humans at this machine (PRD-LOCAL-01): one LocalInput per local slot — the first local slot
## plays as "p1" (arrows/ZXCV + touch), the second as "p2" (WASD/QFGHJ) — plus the gamepad
## auto-assignment across them (GamepadAssigner). The match scene polls, samples and resets them
## together and reads which device each human plays with for telemetry.

var _slots: Array[int] = []
## slot -> LocalInput
var _inputs: Dictionary = {}
var _pads: GamepadAssigner
## Drives touch when no human plays (bots-only scenes) so touch setup always has a target.
var _fallback := LocalInput.new()


## local_slots: MatchSetup.local_slots(); slots past the known prefixes get no input.
func _init(local_slots: Array[int]) -> void:
	var prefixes: Array[String] = []
	for i: int in mini(local_slots.size(), InputBindings.PREFIXES.size()):
		var prefix := InputBindings.PREFIXES[i]
		_slots.append(local_slots[i])
		_inputs[local_slots[i]] = LocalInput.new(prefix)
		prefixes.append(prefix)
	_pads = GamepadAssigner.new(prefixes)


func attach() -> void:
	_pads.attach()


func detach() -> void:
	_pads.detach()


func slots() -> Array[int]:
	return _slots


func input(slot: int) -> LocalInput:
	return _inputs.get(slot) as LocalInput


## The first human's input (touch controls feed it).
func primary() -> LocalInput:
	return input(_slots[0]) if not _slots.is_empty() else _fallback


func pads() -> GamepadAssigner:
	return _pads


func poll() -> void:
	for slot: int in _slots:
		input(slot).poll()


func reset() -> void:
	for slot: int in _slots:
		input(slot).reset()
	_fallback.reset()


func sample(slot: int) -> InputFrame:
	var local := input(slot)
	return local.sample() if local != null else InputFrame.new()


## slot -> "gamepad" | P1's platform default (keyboard / touch) | "keyboard" for other humans.
func input_devices() -> Dictionary:
	var out := {}
	for i: int in _slots.size():
		var fallback := PlatformEnv.default_input_device() if i == 0 else MatchSetup.INPUT_KEYBOARD
		out[_slots[i]] = _pads.input_device(input(_slots[i]).prefix(), fallback)
	return out


## One key-hint entry per human: {prefix, slot, accent}.
func hint_players() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in _slots:
		out.append({"prefix": input(slot).prefix(), "slot": slot, "accent": PlayerStyle.color(slot)})
	return out
