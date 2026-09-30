class_name InputBindings
extends RefCounted
## Default keyboard bindings per local player (PRD §3.2, PRD-LOCAL-01) registered as InputMap
## actions "<prefix>_<name>" at startup. Game code reads actions, never raw keys, so rebinding
## only edits InputMap. Gamepads are bound per device by PadBindings when GamepadAssigner hands
## a pad to a player. The special is the heavy + guard chord on one tick (P1 X+C, P2 G+H).

const PREFIXES: Array[String] = ["p1", "p2"]
const NAMES: Array[String] = ["left", "right", "up", "down", "jump", "light", "heavy", "guard", "grab"]
const SPECIAL_NAMES: Array[String] = ["heavy", "guard"]
const P1 := {
	"p1_left": [KEY_LEFT], "p1_right": [KEY_RIGHT], "p1_up": [KEY_UP], "p1_down": [KEY_DOWN],
	"p1_jump": [KEY_SPACE], "p1_light": [KEY_Z], "p1_heavy": [KEY_X],
	"p1_guard": [KEY_C], "p1_grab": [KEY_V],
}
## P2 on the left of the same keyboard (2026-09-30 user decision): WASD · Q · F · G · H · J.
const P2 := {
	"p2_left": [KEY_A], "p2_right": [KEY_D], "p2_up": [KEY_W], "p2_down": [KEY_S],
	"p2_jump": [KEY_Q], "p2_light": [KEY_F], "p2_heavy": [KEY_G],
	"p2_guard": [KEY_H], "p2_grab": [KEY_J],
}
const KEYS := {"p1": P1, "p2": P2}


static func apply() -> void:
	for prefix: String in PREFIXES:
		var keys: Dictionary = KEYS[prefix]
		for action_name: String in keys:
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			for key: int in keys[action_name]:
				if not _has_key(action_name, key):
					var ev := InputEventKey.new()
					ev.physical_keycode = key
					InputMap.action_add_event(action_name, ev)


static func action(prefix: String, action_name: String) -> String:
	return "%s_%s" % [prefix, action_name]


## Every action of one player, in NAMES order.
static func actions(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for n: String in NAMES:
		out.append(action(prefix, n))
	return out


## The chord that fires the special (both held on the same tick): heavy + guard.
static func special_actions(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for n: String in SPECIAL_NAMES:
		out.append(action(prefix, n))
	return out


## Default keys of an action ([KEY_NONE] when unknown), used when InputMap has none.
static func default_keys(action_name: String) -> Array:
	for prefix: String in PREFIXES:
		var keys: Dictionary = KEYS[prefix]
		if keys.has(action_name):
			return keys[action_name]
	return [KEY_NONE]


static func _has_key(action_name: String, key: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action_name):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false
