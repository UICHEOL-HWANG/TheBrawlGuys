class_name FxPool
extends RefCounted
## Round-robin slots for pooled hit effects: a fixed number of nodes is built once and reused,
## and when every slot is busy the oldest effect is recycled (caps live effects on mobile).

var _size: int
var _next: int = 0


func _init(cap: int) -> void:
	_size = maxi(cap, 1)


func size() -> int:
	return _size


## The slot to (re)use for the next effect.
func acquire() -> int:
	var slot := _next
	_next = (_next + 1) % _size
	return slot
