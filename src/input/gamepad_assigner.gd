class_name GamepadAssigner
extends RefCounted
## Gamepad auto-assignment (PRD-LOCAL-01, PRD §3.2). Rule: pads queue in the order they connect
## (pads already connected at start queue in device-id order). Whenever a player has no pad, the
## earliest queued pad nobody holds goes to the first such player, in player order (P1 first).
## A disconnect frees that player's pad; the next waiting pad (if any) takes over. Players keep
## their keyboard keys the whole time — a pad is added, never swapped for the keys.

const NO_DEVICE := -1
const DEVICE_GAMEPAD := "gamepad"

var _players: Array[String] = []
## Connected pads in connection order.
var _queue: Array[int] = []
## prefix -> device
var _held: Dictionary = {}


## players: action prefixes of the local players, in order ("p1", "p2").
func _init(players: Array[String]) -> void:
	_players = players.duplicate()


## Follows Input.joy_connection_changed until detach(); starts from the pads connected now.
func attach() -> void:
	var pads: Array[int] = []
	pads.assign(Input.get_connected_joypads())
	sync(pads)
	if not Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.connect(_on_joy_changed)


## Stops following connections and removes this assigner's pad bindings.
func detach() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.disconnect(_on_joy_changed)
	for prefix: String in _held.keys():
		PadBindings.unbind(prefix, get_instance_id())
	_held.clear()
	_queue.clear()


## Pads present before we listened: they queue in device-id order.
func sync(devices: Array[int]) -> void:
	var sorted := devices.duplicate()
	sorted.sort()
	for d: int in sorted:
		connect_device(d)


func connect_device(device: int) -> void:
	if _queue.has(device):
		return
	_queue.append(device)
	_fill()


func disconnect_device(device: int) -> void:
	if not _queue.has(device):
		return
	_queue.erase(device)
	var prefix := player_for(device)
	if not prefix.is_empty():
		_held.erase(prefix)
		PadBindings.unbind(prefix, get_instance_id())
	_fill()


func device_for(prefix: String) -> int:
	return int(_held.get(prefix, NO_DEVICE))


## The player holding the pad, "" when it waits (or is unknown).
func player_for(device: int) -> String:
	for prefix: String in _held:
		if int(_held[prefix]) == device:
			return prefix
	return ""


## "gamepad" while the player holds a pad, else `fallback` (keyboard / touch).
func input_device(prefix: String, fallback: String) -> String:
	return DEVICE_GAMEPAD if device_for(prefix) != NO_DEVICE else fallback


func _fill() -> void:
	for prefix: String in _players:
		if _held.has(prefix):
			continue
		var pad := _next_free()
		if pad == NO_DEVICE:
			return
		_held[prefix] = pad
		PadBindings.bind(prefix, pad, get_instance_id())


func _next_free() -> int:
	for d: int in _queue:
		if player_for(d).is_empty():
			return d
	return NO_DEVICE


func _on_joy_changed(device: int, connected: bool) -> void:
	if connected:
		connect_device(device)
	else:
		disconnect_device(device)
