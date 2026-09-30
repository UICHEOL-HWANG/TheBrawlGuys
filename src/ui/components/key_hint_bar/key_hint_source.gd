class_name KeyHintSource
extends RefCounted
## What the KeyHintBar (design.md DS-CMP-16) shows: one entry per keycap, each naming the
## InputMap actions behind it (never raw keys), so rebinding changes the cap text and what lights
## it. A cap with several actions is a chord, pressed only while all of them are held.

## The arrow cluster: these ids sit together under one "이동" caption.
const MOVE_IDS: Array[String] = ["up", "left", "down", "right"]
const MOVE_LABEL := "이동"
## Order = on-screen order. Phase 5 special (PRD-STYLE-04) is one more line:
## {"id": "special", "actions": ["p1_heavy", "p1_guard"], "label": "필살기"},
const HINTS: Array[Dictionary] = [
	{"id": "up", "actions": ["p1_up"], "label": ""},
	{"id": "left", "actions": ["p1_left"], "label": ""},
	{"id": "down", "actions": ["p1_down"], "label": ""},
	{"id": "right", "actions": ["p1_right"], "label": ""},
	{"id": "jump", "actions": ["p1_jump"], "label": "점프"},
	{"id": "light", "actions": ["p1_light"], "label": "약공격"},
	{"id": "heavy", "actions": ["p1_heavy"], "label": "강공격"},
	{"id": "guard", "actions": ["p1_guard"], "label": "가드"},
	{"id": "grab", "actions": ["p1_grab"], "label": "잡기"},
]
const ARROWS := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}


## Every cap resolved against the current InputMap: id, actions, label, text, arrow.
static func caps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hint: Dictionary in HINTS:
		out.append(_resolve(hint))
	return out


static func cap(id: String) -> Dictionary:
	for hint: Dictionary in HINTS:
		if hint["id"] == id:
			return _resolve(hint)
	return {}


static func is_move(id: String) -> bool:
	return MOVE_IDS.has(id)


static func is_held(actions: Array) -> bool:
	if actions.is_empty():
		return false
	for action: String in actions:
		if not InputMap.has_action(action) or not Input.is_action_pressed(action):
			return false
	return true


## "X+C" for a chord, the key name for one action.
static func combo_text(actions: Array) -> String:
	var parts := PackedStringArray()
	for action: String in actions:
		parts.append(OS.get_keycode_string(bound_key(action)))
	return "+".join(parts)


## The first keyboard key bound to the action (the default binding when the action is missing).
static func bound_key(action: String) -> int:
	if InputMap.has_action(action):
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	var defaults: Array = InputBindings.P1.get(action, [KEY_NONE])
	return int(defaults[0])


static func _resolve(hint: Dictionary) -> Dictionary:
	var actions: Array = hint["actions"]
	var arrow := Vector2.ZERO
	if actions.size() == 1:
		arrow = ARROWS.get(bound_key(String(actions[0])), Vector2.ZERO)
	return {
		"id": hint["id"], "actions": actions, "label": hint["label"],
		"text": combo_text(actions), "arrow": arrow,
	}
