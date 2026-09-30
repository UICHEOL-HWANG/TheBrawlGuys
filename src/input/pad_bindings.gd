class_name PadBindings
extends RefCounted
## Gamepad events of one local player (PRD §3.2): left stick / d-pad move, A jump, X light, Y heavy,
## RB guard, B grab (special = Y+RB on one tick). Bound to one device id, so two pads drive two
## players; GamepadAssigner decides which. Keyboard events of the actions are never touched.
## InputMap is global, so each player's pad binding remembers its owner (an assigner's instance
## id): a stale owner's unbind cannot strip a newer match's pad.

const BUTTONS := {
	"jump": [JOY_BUTTON_A], "light": [JOY_BUTTON_X], "heavy": [JOY_BUTTON_Y],
	"guard": [JOY_BUTTON_RIGHT_SHOULDER], "grab": [JOY_BUTTON_B],
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
}
## name -> [axis, direction]
const AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
}
## 0 = no particular owner (any unbind may remove it).
const ANY_OWNER := 0

## prefix -> owner id of the current pad binding
static var _owners: Dictionary = {}


## Replaces the player's pad events with ones for `device`.
static func bind(prefix: String, device: int, owner: int = ANY_OWNER) -> void:
	unbind(prefix)
	_owners[prefix] = owner
	for n: String in InputBindings.NAMES:
		var action_name := InputBindings.action(prefix, n)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for button: int in BUTTONS.get(n, []):
			var ev := InputEventJoypadButton.new()
			ev.device = device
			ev.button_index = button as JoyButton
			InputMap.action_add_event(action_name, ev)
		if AXES.has(n):
			var motion := InputEventJoypadMotion.new()
			motion.device = device
			motion.axis = AXES[n][0] as JoyAxis
			motion.axis_value = float(AXES[n][1])
			InputMap.action_add_event(action_name, motion)


## Removes every pad event from the player's actions (keys stay) and releases those actions so a
## button held while the pad went away does not stay pressed. With an owner, only that owner's
## binding is removed.
static func unbind(prefix: String, owner: int = ANY_OWNER) -> void:
	if owner != ANY_OWNER and int(_owners.get(prefix, ANY_OWNER)) != owner:
		return
	_owners.erase(prefix)
	for action_name: String in InputBindings.actions(prefix):
		if not InputMap.has_action(action_name):
			continue
		var erased := false
		for ev: InputEvent in InputMap.action_get_events(action_name):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action_name, ev)
				erased = true
		if erased:
			Input.action_release(action_name)
