class_name KeyHintSource
extends RefCounted
## What the KeyHintBar (design.md DS-CMP-16) shows: one entry per keycap, each naming the
## InputMap actions behind it (never raw keys), so rebinding changes the cap text and what lights
## it. A cap with several actions is a chord, pressed only while all of them are held — the
## special (PRD-STYLE-04) is the heavy + guard chord. Caps are built for one player's action
## prefix (PRD-LOCAL-01: "p1" X+C, "p2" G+H).

## The arrow cluster: these ids sit together under one "이동" caption.
const MOVE_IDS: Array[String] = ["up", "left", "down", "right"]
const MOVE_LABEL := "이동"
## The special chord cap: it also rings while the player's gauge is full.
const SPECIAL_ID := "special"
const DEFAULT_PREFIX := "p1"
## Order = on-screen order; "names" are action names without the player prefix.
const HINTS: Array[Dictionary] = [
	{"id": "up", "names": ["up"], "label": ""},
	{"id": "left", "names": ["left"], "label": ""},
	{"id": "down", "names": ["down"], "label": ""},
	{"id": "right", "names": ["right"], "label": ""},
	{"id": "jump", "names": ["jump"], "label": "점프"},
	{"id": "light", "names": ["light"], "label": "약공격"},
	{"id": "heavy", "names": ["heavy"], "label": "강공격"},
	{"id": "guard", "names": ["guard"], "label": "가드 · +방향 구르기 · 착지 직전 낙법"},
	{"id": "grab", "names": ["grab"], "label": "잡기"},
	{"id": SPECIAL_ID, "names": ["heavy", "guard"], "label": "필살기"},
]
const ARROWS := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}


## Every cap of one player resolved against the current InputMap: id, actions, label, text, arrow.
static func caps(prefix: String = DEFAULT_PREFIX) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hint: Dictionary in HINTS:
		out.append(_resolve(hint, prefix))
	return out


static func cap(id: String, prefix: String = DEFAULT_PREFIX) -> Dictionary:
	for hint: Dictionary in HINTS:
		if hint["id"] == id:
			return _resolve(hint, prefix)
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
	return int(InputBindings.default_keys(action)[0])


static func _resolve(hint: Dictionary, prefix: String) -> Dictionary:
	var actions: Array = []
	for n: String in hint["names"]:
		actions.append(InputBindings.action(prefix, n))
	var arrow := Vector2.ZERO
	if actions.size() == 1:
		arrow = ARROWS.get(bound_key(String(actions[0])), Vector2.ZERO)
	return {
		"id": hint["id"], "actions": actions, "label": hint["label"],
		"text": combo_text(actions), "arrow": arrow,
	}
