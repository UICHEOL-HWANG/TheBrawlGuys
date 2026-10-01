extends WsPort
## Test double for RealtimeChannel's socket: records sent frames, hands back queued ones.

var url: String = ""
var sent: PackedStringArray = PackedStringArray()
var socket_state: WsPort.State = WsPort.State.CONNECTING
var open_error: Error = OK
var _inbox: PackedStringArray = PackedStringArray()


func open(p_url: String) -> Error:
	url = p_url
	return open_error


func poll() -> void:
	pass


func state() -> WsPort.State:
	return socket_state


func send_text(text: String) -> Error:
	sent.append(text)
	return OK


func receive() -> PackedStringArray:
	var out := _inbox
	_inbox = PackedStringArray()
	return out


func close() -> void:
	socket_state = WsPort.State.CLOSED


## Queues a frame the next poll() reads.
func push(text: String) -> void:
	_inbox.append(text)


func last() -> Dictionary:
	return PhoenixMessage.decode(sent[sent.size() - 1]) if not sent.is_empty() else {}


func events() -> PackedStringArray:
	var out := PackedStringArray()
	for text: String in sent:
		out.append(String(PhoenixMessage.decode(text).get("event", "")))
	return out
