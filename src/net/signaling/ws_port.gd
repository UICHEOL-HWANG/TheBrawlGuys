class_name WsPort
extends RefCounted
## Text WebSocket seam for RealtimeChannel: production wraps WebSocketPeer (works in the Web export
## and on desktop), tests inject a fake socket so no test touches the network.

enum State { CONNECTING, OPEN, CLOSING, CLOSED }

var _ws: WebSocketPeer = null


func open(url: String) -> Error:
	_ws = WebSocketPeer.new()
	return _ws.connect_to_url(url)


func poll() -> void:
	if _ws != null:
		_ws.poll()


func state() -> State:
	if _ws == null:
		return State.CLOSED
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return State.CONNECTING
		WebSocketPeer.STATE_OPEN:
			return State.OPEN
		WebSocketPeer.STATE_CLOSING:
			return State.CLOSING
	return State.CLOSED


func send_text(text: String) -> Error:
	return _ws.send_text(text) if _ws != null else ERR_UNCONFIGURED


## Text frames received since the last call.
func receive() -> PackedStringArray:
	var out := PackedStringArray()
	if _ws == null:
		return out
	while _ws.get_available_packet_count() > 0:
		out.append(_ws.get_packet().get_string_from_utf8())
	return out


func close() -> void:
	if _ws != null:
		_ws.close()
