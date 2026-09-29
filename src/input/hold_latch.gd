class_name HoldLatch
extends RefCounted
## A held button (heavy, guard) carried from rendered frames to sim ticks (context E3). consume()
## is true while the button is held, and also once for a press released before any tick ran, so
## a quick tap still reaches the sim as a one-tick hold.

var _held: bool = false
var _pending: bool = false


func press() -> void:
	_pending = true


func set_held(held: bool) -> void:
	if held and not _held:
		_pending = true
	_held = held


func consume() -> bool:
	var value := _held or _pending
	_pending = false
	return value


func clear() -> void:
	_held = false
	_pending = false


func is_held() -> bool:
	return _held
