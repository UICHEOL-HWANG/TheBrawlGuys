class_name LoopbackServer
extends RefCounted
## Desktop OAuth callback (platform A4): listens on 127.0.0.1:port, reads the browser's
## "GET /callback?code=..." request line, answers with a short page and stops. Polled per frame.
## poll() returns {} while waiting, {"code": ...} on success or {"error": reason}.

const TIMEOUT_MS := 180_000
const DONE_MESSAGE := "로그인 완료, 게임으로 돌아가세요"
const FAIL_MESSAGE := "로그인 실패 — 게임에서 다시 시도해 주세요"
const MAX_REQUEST_BYTES := 8192

var _server: TCPServer = null
var _peer: StreamPeerTCP = null
var _buffer: PackedByteArray = PackedByteArray()
var _deadline_ms: int = 0


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
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	if _server != null:
		_server.stop()
	_server = null
	_buffer.clear()


func poll(now_ms: int) -> Dictionary:
	if _server == null:
		return {"error": "not_listening"}
	if now_ms >= _deadline_ms:
		stop()
		return {"error": "timeout"}
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_buffer.clear()
	if _peer == null:
		return {}
	_peer.poll()
	var available := _peer.get_available_bytes()
	if available > 0:
		_buffer.append_array(_peer.get_data(available)[1])
	var text := _buffer.get_string_from_utf8()
	if not text.contains("\r\n") and _buffer.size() < MAX_REQUEST_BYTES:
		return {}
	return _answer(parse_request_line(text.get_slice("\r\n", 0)))


func _answer(result: Dictionary) -> Dictionary:
	if result.is_empty():
		_peer.put_data(http_response(404, "").to_utf8_buffer())
		_peer.disconnect_from_host()
		_peer = null
		return {}
	var message := DONE_MESSAGE if result.has("code") else FAIL_MESSAGE
	_peer.put_data(http_response(200, message).to_utf8_buffer())
	stop()
	return result


## "GET /callback?code=X HTTP/1.1" -> {"code": X}; provider errors -> {"error": ...};
## anything else (favicon, other methods) -> {} so the server keeps waiting.
static func parse_request_line(line: String) -> Dictionary:
	var parts := line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		return {}
	var target := parts[1]
	if target.get_slice("?", 0) != AuthUrls.CALLBACK_PATH:
		return {}
	var query := WebCallback.parse_query(target.substr(target.find("?")) if target.contains("?") else "")
	if query.has("error"):
		return {"error": String(query["error"])}
	if String(query.get("code", "")).is_empty():
		return {"error": "missing_code"}
	return {"code": String(query["code"])}


static func http_response(status: int, message: String) -> String:
	var body := "" if message.is_empty() else \
			"<!doctype html><html><head><meta charset=\"utf-8\"><title>TheBrawlGuys</title></head>" \
			+ "<body><h1>%s</h1></body></html>" % message
	var reason := "OK" if status == 200 else "Not Found"
	return "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		status, reason, body.to_utf8_buffer().size(), body]
