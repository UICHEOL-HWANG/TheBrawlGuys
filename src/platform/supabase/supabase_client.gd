class_name SupabaseClient
extends RefCounted
## Supabase HTTP client (platform A3, PRD-DATA-04): Auth token grants (/auth/v1/token) and REST
## inserts (/rest/v1) with the anon key plus the user's bearer token. Row-level security on the
## server limits writes to the signed-in user. Callbacks: done(ok: bool, status: int, message: String).

signal session_changed(session: SupabaseSession)

const CHUNK_ROWS := 500
## Refresh this many seconds before the access token expires.
const REFRESH_MARGIN_S := 60
## Status reported when an insert is attempted without a session (no request is made).
const STATUS_NO_SESSION := -1
const HTTP_UNAUTHORIZED := 401
const HTTP_BAD_REQUEST := 400

var session: SupabaseSession = null
var now_s: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## (endpoint: String, status: int); reports to Amplitude net_error by default.
var net_error_sink: Callable = func(endpoint: String, status: int) -> void:
	Analytics.track("net_error", {"endpoint": endpoint, "status": status})

var _url: String
var _anon_key: String
var _transport: HttpTransport


func _init(url: String, anon_key: String, transport: HttpTransport) -> void:
	_url = url.trim_suffix("/")
	_anon_key = anon_key
	_transport = transport


func has_session() -> bool:
	return session != null


func url() -> String:
	return _url


func exchange_pkce(auth_code: String, code_verifier: String, done: Callable) -> void:
	_token_grant("pkce", {"auth_code": auth_code, "code_verifier": code_verifier}, done)


func refresh(done: Callable) -> void:
	if session == null:
		done.call(false, STATUS_NO_SESSION, "not signed in")
		return
	_token_grant("refresh_token", {"refresh_token": session.refresh_token}, done)


func sign_out() -> void:
	session = null
	session_changed.emit(null)


## Inserts rows in CHUNK_ROWS-sized requests, one after another; done fires once.
func rest_insert(table: String, rows: Array, done: Callable) -> void:
	if session == null:
		done.call(false, STATUS_NO_SESSION, "not signed in")
		return
	_insert_from(table, rows, 0, false, done)


func _insert_from(table: String, rows: Array, start: int, retried: bool, done: Callable) -> void:
	if start >= rows.size():
		done.call(true, 201, "")
		return
	_with_fresh_token(func(ok: bool, status: int, message: String) -> void:
		if not ok:
			done.call(false, status, message)
			return
		var chunk := rows.slice(start, start + CHUNK_ROWS)
		_transport.request("%s/rest/v1/%s" % [_url, table], _rest_headers(), HTTPClient.METHOD_POST,
				JSON.stringify(chunk), func(code: int, body: String) -> void:
					_on_insert(table, rows, start, retried, done, code, body)))


func _on_insert(table: String, rows: Array, start: int, retried: bool, done: Callable,
		code: int, body: String) -> void:
	if code >= 200 and code < 300:
		_insert_from(table, rows, start + CHUNK_ROWS, false, done)
	elif code == HTTP_UNAUTHORIZED and not retried and session != null:
		refresh(func(ok: bool, status: int, message: String) -> void:
			if ok:
				_insert_from(table, rows, start, true, done)
			else:
				done.call(false, status, message))
	else:
		_net_error("rest/" + table, code)
		done.call(false, code, body)


func _with_fresh_token(then: Callable) -> void:
	if session != null and session.is_expiring(int(now_s.call()), REFRESH_MARGIN_S):
		refresh(then)
	else:
		then.call(true, 200, "")


func _token_grant(grant: String, payload: Dictionary, done: Callable) -> void:
	var headers := PackedStringArray(["apikey: " + _anon_key, "Content-Type: application/json"])
	_transport.request("%s/auth/v1/token?grant_type=%s" % [_url, grant], headers, HTTPClient.METHOD_POST,
			JSON.stringify(payload), func(code: int, body: String) -> void:
				_on_token(code, body, done))


func _on_token(code: int, body: String, done: Callable) -> void:
	if code < 200 or code >= 300:
		_net_error("auth/token", code)
		if session != null and (code == HTTP_BAD_REQUEST or code == HTTP_UNAUTHORIZED):
			sign_out()  # the refresh token is no longer valid
		done.call(false, code, body)
		return
	var fresh := SupabaseSession.from_token_response(JsonSafe.parse(body), int(now_s.call()))
	if fresh == null:
		push_warning("SupabaseClient: token response without session fields")
		done.call(false, code, "malformed token response")
		return
	session = fresh
	session_changed.emit(session)
	done.call(true, code, "")


func _rest_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + _anon_key, "Authorization: Bearer " + session.access_token,
		"Content-Type: application/json", "Prefer: return=minimal",
	])


func _net_error(endpoint: String, status: int) -> void:
	if net_error_sink.is_valid():
		net_error_sink.call(endpoint, status)
