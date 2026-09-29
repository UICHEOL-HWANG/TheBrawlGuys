class_name ButtonLatch
extends RefCounted
## Carries a button press from the frame it happened in to the next sim tick (context D6).
## Frames can run zero or several fixed ticks, so edges must be latched, not polled per tick.

var _pending: bool = false


func press() -> void:
	_pending = true


func consume() -> bool:
	var was := _pending
	_pending = false
	return was
