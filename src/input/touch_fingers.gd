class_name TouchFingers
extends RefCounted
## Raw touch id (InputEvent index) -> finger 0..max-1, from press to release (TouchInput). iOS
## Safari reports big arbitrary Touch.identifier values, Android 0, 1, 2; either way a press
## takes the lowest free finger and keeps it until its release.

const NONE := -1

var _max: int
var _fingers: Dictionary = {}


func _init(max_fingers: int) -> void:
	_max = max_fingers


## The finger a raw touch id presses with: its own if already down, else the lowest free one
## (NONE when all are taken).
func claim(id: int) -> int:
	if _fingers.has(id):
		return int(_fingers[id])
	for f: int in _max:
		if not _fingers.values().has(f):
			_fingers[id] = f
			return f
	return NONE


## The finger a raw touch id holds (NONE when it is not down).
func of(id: int) -> int:
	return int(_fingers[id]) if _fingers.has(id) else NONE


func release(id: int) -> void:
	_fingers.erase(id)


func clear() -> void:
	_fingers.clear()
