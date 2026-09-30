class_name BatchQueue
extends RefCounted
## Offline event queue (platform A2): capped FIFO persisted as a JSON array, with exponential
## backoff after failed sends. Holds already-built Amplitude events.

const DEFAULT_PATH := "user://analytics_queue.json"
const DEFAULT_CAP := 2000
const BACKOFF_BASE_MS := 2000
const BACKOFF_MAX_MS := 300_000

var _path: String
var _cap: int
var _events: Array[Dictionary] = []
var _failures: int = 0
var _next_attempt_ms: int = 0
var _dropped: int = 0


## An empty path keeps the queue in memory only.
func _init(path: String = DEFAULT_PATH, cap: int = DEFAULT_CAP) -> void:
	_path = path
	_cap = maxi(cap, 1)


func push(event: Dictionary) -> void:
	_events.append(event)
	var over := _events.size() - _cap
	if over > 0:
		_events = _events.slice(over)
		_dropped += over
		push_warning("BatchQueue: cap %d reached, dropped %d oldest events" % [_cap, over])


func size() -> int:
	return _events.size()


func peek(count: int) -> Array[Dictionary]:
	return _events.slice(0, count)


func drop_front(count: int) -> void:
	_events = _events.slice(count)


func dropped_count() -> int:
	return _dropped


func can_send(now_ms: int) -> bool:
	return now_ms >= _next_attempt_ms


func next_attempt_ms() -> int:
	return _next_attempt_ms


func mark_failure(now_ms: int) -> void:
	var delay := BACKOFF_BASE_MS * int(pow(2.0, mini(_failures, 20)))
	_failures += 1
	_next_attempt_ms = now_ms + mini(delay, BACKOFF_MAX_MS)


func mark_success() -> void:
	_failures = 0
	_next_attempt_ms = 0


func save() -> Error:
	if _path.is_empty():
		return OK
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_warning("BatchQueue: cannot write %s (%s)" % [_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(_events))
	f.close()
	return OK


## Appends events saved by an earlier run; returns how many were loaded.
func restore() -> int:
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return 0
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(_path)) == OK else null
	if not (parsed is Array):
		push_warning("BatchQueue: %s is not a JSON array, offline events discarded" % _path)
		return 0
	var loaded := 0
	for e: Variant in (parsed as Array):
		if e is Dictionary:
			push(e)
			loaded += 1
	return loaded
