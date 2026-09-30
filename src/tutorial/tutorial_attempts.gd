class_name TutorialAttempts
extends RefCounted
## How many tries a tutorial goal took (tutorial_step_completed.attempts): new presses of the goal's
## buttons, from one tick's InputFrame to the next. "move" = the stick or keys leave neutral,
## "special" = heavy and guard become held together, anything else = that InputFrame button.


static func presses(names: Array, before: InputFrame, now: InputFrame) -> int:
	var n := 0
	for name: String in names:
		if _held(name, now) and not _held(name, before):
			n += 1
	return n


static func _held(name: String, f: InputFrame) -> bool:
	if f == null:
		return false
	match name:
		"move":
			return f.move_x != 0.0 or f.move_z != 0.0
		"special":
			return f.heavy and f.guard
		"jump":
			return f.jump
		"light":
			return f.light
		"heavy":
			return f.heavy
		"guard":
			return f.guard
		"grab":
			return f.grab
	push_warning("TutorialAttempts: unknown button '%s'" % name)
	return false
