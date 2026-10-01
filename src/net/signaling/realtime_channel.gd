class_name RealtimeChannel
extends RefCounted
## Minimal Supabase Realtime client (Phase 6 online signaling): one WebSocket, one Phoenix channel
## (realtime:room:<CODE>) used for broadcast only. Call poll(now_ms) every frame: it opens the
## socket, joins, sends a heartbeat every HEARTBEAT_MS and turns broadcast frames into `message`.
## A missed heartbeat reply, a refused join or a dropped socket ends in `failed(reason)`.

signal joined
signal failed(reason: String)
## A broadcast from another client in the room.
signal message(event: String, payload: Dictionary)

enum State { IDLE, CONNECTING, JOINING, JOINED, CLOSED }

const HEARTBEAT_MS := 25_000
const JOIN_TIMEOUT_MS := 10_000
const REASON_SOCKET := "socket"
const REASON_JOIN := "join_refused"
const REASON_TIMEOUT := "join_timeout"
const REASON_HEARTBEAT := "heartbeat"
const REASON_CLOSED := "server_closed"

var _port: WsPort
var _state: State = State.IDLE
var _topic: String = ""
var _token: String = ""
var _ref: int = 0
var _join_ref: String = ""
var _heartbeat_ref: String = ""
var _next_heartbeat_ms: int = 0
var _deadline_ms: int = 0


func _init(port: WsPort = null) -> void:
	_port = port if port != null else WsPort.new()


## Opens the socket at url and joins topic once it is open. access_token: the user's JWT or "".
func open(url: String, topic: String, access_token: String, now_ms: int) -> void:
	_topic = topic
	_token = access_token
	_deadline_ms = now_ms + JOIN_TIMEOUT_MS
	if _port.open(url) != OK:
		_fail(REASON_SOCKET)
		return
	_state = State.CONNECTING


func state() -> State:
	return _state


func is_joined() -> bool:
	return _state == State.JOINED


func topic() -> String:
	return _topic


func poll(now_ms: int) -> void:
	if _state == State.IDLE or _state == State.CLOSED:
		return
	_port.poll()
	var ws := _port.state()
	if ws == WsPort.State.CLOSED or ws == WsPort.State.CLOSING:
		_fail(REASON_SOCKET)
		return
	if _state == State.CONNECTING and ws == WsPort.State.OPEN:
		_join_ref = _next_ref()
		_port.send_text(PhoenixMessage.join(_topic, _join_ref, _token))
		_state = State.JOINING
		_next_heartbeat_ms = now_ms + HEARTBEAT_MS
	for text: String in _port.receive():
		_handle(PhoenixMessage.decode(text))
		if _state == State.CLOSED:
			return
	_tick_timers(now_ms)


## Sends a broadcast to every other client in the room; false when not joined.
func broadcast(event: String, payload: Dictionary) -> bool:
	if _state != State.JOINED:
		return false
	return _port.send_text(PhoenixMessage.broadcast(_topic, event, payload, _next_ref(), _join_ref)) == OK


func close() -> void:
	if _state == State.JOINED:
		_port.send_text(PhoenixMessage.leave(_topic, _next_ref(), _join_ref))
	if _state != State.CLOSED:
		_port.close()
	_state = State.CLOSED


func _tick_timers(now_ms: int) -> void:
	if _state != State.JOINED and now_ms >= _deadline_ms:
		_fail(REASON_TIMEOUT)
		return
	if _state == State.JOINING or _state == State.JOINED:
		if now_ms < _next_heartbeat_ms:
			return
		if not _heartbeat_ref.is_empty():
			_fail(REASON_HEARTBEAT)  # the previous heartbeat was never answered
			return
		_heartbeat_ref = _next_ref()
		_port.send_text(PhoenixMessage.heartbeat(_heartbeat_ref))
		_next_heartbeat_ms = now_ms + HEARTBEAT_MS


func _handle(msg: Dictionary) -> void:
	if msg.is_empty():
		return
	var event := String(msg["event"])
	var ref := String(msg["ref"])
	if event == PhoenixMessage.EV_REPLY and ref == _heartbeat_ref:
		_heartbeat_ref = ""
	elif String(msg["topic"]) != _topic:
		return
	elif event == PhoenixMessage.EV_REPLY and ref == _join_ref and _state == State.JOINING:
		if PhoenixMessage.is_ok_reply(msg):
			_state = State.JOINED
			joined.emit()
		else:
			_fail(REASON_JOIN)
	elif event == PhoenixMessage.EV_BROADCAST:
		var p: Dictionary = msg["payload"]
		var inner: Variant = p.get("payload", {})
		message.emit(String(p.get("event", "")), inner if inner is Dictionary else {})
	elif event == PhoenixMessage.EV_ERROR or event == PhoenixMessage.EV_CLOSE:
		_fail(REASON_CLOSED)


func _fail(reason: String) -> void:
	if _state == State.CLOSED:
		return
	_port.close()
	_state = State.CLOSED
	failed.emit(reason)


func _next_ref() -> String:
	_ref += 1
	return str(_ref)
