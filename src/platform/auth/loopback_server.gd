class_name LoopbackServer
extends RefCounted
## Desktop OAuth callback (platform A4): listens on 127.0.0.1:port, reads the browser's
## "GET /callback?code=..." request line, answers with a short page and stops. Polled per frame.
## poll() returns {} while waiting, {"code": ...} on success or {"error": reason}.

const TIMEOUT_MS := 180_000
const MAX_REQUEST_BYTES := 8192
## A connection must deliver its request line within this time.
const PEER_TIMEOUT_MS := 2000

var _server: TCPServer = null
var _peer: StreamPeerTCP = null
var _buffer: PackedByteArray = PackedByteArray()
var _deadline_ms: int = 0
var _peer_deadline_ms: int = 0
## Only callbacks carrying this state nonce count; others are answered 404 and ignored.
var _expected_state: String = ""


func expect_state(nonce: String) -> void:
	_expected_state = nonce


func expected_state() -> String:
	return _expected_state


func start(port: int, now_ms: int) -> Error:
	stop()
	_server = TCPServer.new()
	var err := _server.listen(port, AuthUrls.LOOPBACK_HOST)
	if err != OK:
		_server = null
		return err
	_deadline_ms = now_ms + TIMEOUT_MS
	return OK


func stop() -> void:
	_drop_peer()
	if _server != null:
		_server.stop()
	_server = null


func poll(now_ms: int) -> Dictionary:
	if _server == null:
		return {"error": "not_listening"}
	if now_ms >= _deadline_ms:
		stop()
		return {"error": "timeout"}
	_take_new_peer(now_ms)
	if _peer == null:
		return {}
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or now_ms >= _peer_deadline_ms:
		_drop_peer()  # closed, or an idle browser preconnect
		return {}
	var available := _peer.get_available_bytes()
	if available > 0:
		_buffer.append_array(_peer.get_data(available)[1])
	var text := _buffer.get_string_from_utf8()
	if not text.contains("\r\n") and _buffer.size() < MAX_REQUEST_BYTES:
		return {}
	return _answer(parse_request_line(text.get_slice("\r\n", 0), _expected_state))


## A newer connection replaces a peer that has sent nothing yet (browsers open spare sockets).
func _take_new_peer(now_ms: int) -> void:
	if not _server.is_connection_available() or (_peer != null and not _buffer.is_empty()):
		return
	_drop_peer()
	_peer = _server.take_connection()
	_peer_deadline_ms = now_ms + PEER_TIMEOUT_MS


func _drop_peer() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	_buffer.clear()


func _answer(result: Dictionary) -> Dictionary:
	if result.is_empty():
		_peer.put_data(http_response(404, "").to_utf8_buffer())
		_drop_peer()
		return {}
	_peer.put_data(http_response(200, CallbackPage.html(result.has("code"))).to_utf8_buffer())
	stop()
	return result


## "GET /callback?code=X HTTP/1.1" -> {"code": X}; provider errors -> {"error": ...};
## anything else (favicon, other methods, a missing or wrong state nonce) -> {} so the server
## keeps waiting: a stray or forged request can neither finish nor abort the sign-in.
static func parse_request_line(line: String, expected_state: String = "") -> Dictionary:
	var parts := line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		return {}
	var target := parts[1]
	if target.get_slice("?", 0) != AuthUrls.CALLBACK_PATH:
		return {}
	var query := WebCallback.parse_query(target.substr(target.find("?")) if target.contains("?") else "")
	if not expected_state.is_empty() and String(query.get(AuthUrls.STATE_PARAM, "")) != expected_state:
		return {}
	if query.has("error"):
		return {"error": String(query["error"])}
	if String(query.get("code", "")).is_empty():
		return {"error": "missing_code"}
	return {"code": String(query["code"])}


## body is a full HTML document (CallbackPage) or "" for the 404 answer.
static func http_response(status: int, body: String) -> String:
	var reason := "OK" if status == 200 else "Not Found"
	return "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		status, reason, body.to_utf8_buffer().size(), body]
