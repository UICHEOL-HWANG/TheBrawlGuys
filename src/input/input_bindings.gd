class_name InputBindings
extends RefCounted
## Default P1 keyboard bindings (PRD §3.2) registered as InputMap actions at startup.
## Game code reads actions, never raw keys, so rebinding only edits InputMap.

const P1 := {
	"p1_left": [KEY_LEFT], "p1_right": [KEY_RIGHT], "p1_up": [KEY_UP], "p1_down": [KEY_DOWN],
	"p1_jump": [KEY_SPACE], "p1_light": [KEY_Z], "p1_heavy": [KEY_X],
	"p1_guard": [KEY_C], "p1_grab": [KEY_V],
}


static func apply() -> void:
	for action: String in P1:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in P1[action]:
			if not _has_key(action, key):
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


static func _has_key(action: String, key: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false
