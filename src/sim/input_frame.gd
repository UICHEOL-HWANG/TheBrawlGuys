class_name InputFrame
extends RefCounted
## One tick of player intent. Keyboard, touch, bot and network all produce this (PRD §3.1).

var move_x: float = 0.0
var move_z: float = 0.0
var jump: bool = false
var light: bool = false
var heavy: bool = false
var guard: bool = false
var grab: bool = false


static func neutral() -> InputFrame:
	return InputFrame.new()


func copy() -> InputFrame:
	var f := InputFrame.new()
	f.move_x = move_x
	f.move_z = move_z
	f.jump = jump
	f.light = light
	f.heavy = heavy
	f.guard = guard
	f.grab = grab
	return f
