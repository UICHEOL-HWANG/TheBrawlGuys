extends RealtimeChannel
## Test double for a joined Realtime channel: every channel sharing `bus` (an Array) receives the
## others' broadcasts (JSON round trip, like the wire); open() joins at once.

var bus: Array = []
var opened_url: String = ""
var opened_token: String = ""
var _open: bool = false


func open(url: String, _p_topic: String, access_token: String, _now_ms: int) -> void:
	opened_url = url
	opened_token = access_token
	_open = true
	bus.append(self)
	joined.emit()


func poll(_now_ms: int) -> void:
	pass


func is_joined() -> bool:
	return _open


func broadcast(event: String, payload: Dictionary) -> bool:
	if not _open:
		return false
	for other: Object in bus.duplicate():
		if other != self:
			other.emit_signal("message", event, JSON.parse_string(JSON.stringify(payload)))
	return true


func close() -> void:
	_open = false
	bus.erase(self)
