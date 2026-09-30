extends GutTest
## Supabase REST/Auth client (platform A3): chunked inserts, auth headers, token refresh, errors.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const URL := "https://proj.supabase.co"
const NOW := 1_700_000_000

var _http: FakeHttp
var _client: SupabaseClient
var _results: Array = []
var _net_errors: Array = []


func before_each() -> void:
	_http = FakeHttp.new()
	_results.clear()
	_net_errors.clear()
	_client = SupabaseClient.new(URL, "anon-key", _http)
	_client.now_s = func() -> int: return NOW
	_client.net_error_sink = func(endpoint: String, status: int) -> void: _net_errors.append([endpoint, status])


func _sign_in(expires_at: int = NOW + 3600) -> void:
	_client.session = SupabaseSession.new("access-1", "refresh-1", expires_at, "user-1")


func _done() -> Callable:
	return func(ok: bool, status: int, message: String) -> void: _results.append([ok, status, message])


func _rows(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append({"i": i})
	return out


func _token_json(access: String, refresh: String) -> String:
	return JSON.stringify({"access_token": access, "refresh_token": refresh, "expires_in": 3600,
		"user": {"id": "user-1"}})


func test_insert_is_chunked_with_auth_headers() -> void:
	_sign_in()
	_client.rest_insert("match_events", _rows(1200), _done())
	assert_eq(_http.requests.size(), 1, "chunks go one after another")
	var r := _http.last()
	assert_eq(r["url"], URL + "/rest/v1/match_events")
	assert_eq(r["method"], HTTPClient.METHOD_POST)
	assert_eq(_http.header(r, "apikey"), "anon-key")
	assert_eq(_http.header(r, "Authorization"), "Bearer access-1")
	assert_eq(_http.header(r, "Prefer"), "return=minimal")
	assert_eq((_http.last_json() as Array).size(), SupabaseClient.CHUNK_ROWS)
	_http.respond(201)
	_http.respond(201)
	assert_eq((_http.last_json() as Array).size(), 200)
	assert_eq(_results.size(), 0, "not done before the last chunk")
	_http.respond(201)
	assert_eq(_http.requests.size(), 3)
	assert_eq(_results, [[true, 201, ""]])


func test_insert_without_session_fails_fast() -> void:
	_client.rest_insert("matches", _rows(1), _done())
	assert_eq(_http.requests.size(), 0)
	assert_eq(_results.size(), 1)
	assert_false(_results[0][0])
	assert_eq(_results[0][1], SupabaseClient.STATUS_NO_SESSION)


func test_expiring_token_is_refreshed_first() -> void:
	_sign_in(NOW + 10)
	var changed: Array = []
	_client.session_changed.connect(func(s: SupabaseSession) -> void: changed.append(s))
	_client.rest_insert("matches", _rows(1), _done())
	var r := _http.last()
	assert_eq(r["url"], URL + "/auth/v1/token?grant_type=refresh_token")
	assert_eq(_http.header(r, "apikey"), "anon-key")
	assert_eq((_http.last_json() as Dictionary)["refresh_token"], "refresh-1")
	_http.respond(200, _token_json("access-2", "refresh-2"))
	assert_eq(changed.size(), 1)
	assert_eq(_client.session.refresh_token, "refresh-2")
	assert_eq(_client.session.expires_at, NOW + 3600)
	assert_eq(_http.header(_http.last(), "Authorization"), "Bearer access-2")
	_http.respond(201)
	assert_true(_results[0][0])


func test_unauthorized_insert_refreshes_and_retries_once() -> void:
	_sign_in()
	_client.rest_insert("matches", _rows(1), _done())
	_http.respond(401, "{\"message\":\"JWT expired\"}")
	assert_string_contains(String(_http.last()["url"]), "grant_type=refresh_token")
	_http.respond(200, _token_json("access-2", "refresh-2"))
	assert_eq(_http.header(_http.last(), "Authorization"), "Bearer access-2")
	_http.respond(401, "{}")
	assert_eq(_results.size(), 1)
	assert_false(_results[0][0], "a second 401 is an error")
	assert_eq(_results[0][1], 401)


func test_server_error_surfaces_status_and_tracks_net_error() -> void:
	_sign_in()
	_client.rest_insert("matches", _rows(1), _done())
	_http.respond(500, "{\"message\":\"boom\"}")
	assert_eq(_results.size(), 1)
	assert_eq(_results[0][0], false)
	assert_eq(_results[0][1], 500)
	assert_string_contains(String(_results[0][2]), "boom")
	assert_eq(_net_errors, [["rest/matches", 500]])


func test_rejected_refresh_signs_out() -> void:
	_sign_in(NOW)
	_client.rest_insert("matches", _rows(1), _done())
	_http.respond(400, "{\"error\":\"invalid_grant\"}")
	assert_null(_client.session)
	assert_false(_results[0][0])
	assert_eq(_net_errors, [["auth/token", 400]])


func test_pkce_exchange_stores_the_session() -> void:
	_client.exchange_pkce("code-1", "verifier-1", _done())
	var r := _http.last()
	assert_eq(r["url"], URL + "/auth/v1/token?grant_type=pkce")
	var body: Dictionary = _http.last_json()
	assert_eq(body["auth_code"], "code-1")
	assert_eq(body["code_verifier"], "verifier-1")
	_http.respond(200, _token_json("access-9", "refresh-9"))
	assert_true(_client.has_session())
	assert_eq(_client.session.user_id, "user-1")
	assert_eq(_client.session.access_token, "access-9")
	assert_true(_results[0][0])


func test_malformed_token_response_is_an_error() -> void:
	_client.exchange_pkce("code-1", "verifier-1", _done())
	_http.respond(200, "{\"nope\":1}")
	assert_false(_client.has_session())
	assert_false(_results[0][0])


func test_session_dictionary_round_trip() -> void:
	var s := SupabaseSession.new("a", "r", 123, "u")
	var back := SupabaseSession.from_dict(s.to_dict())
	assert_eq(back.access_token, "a")
	assert_eq(back.refresh_token, "r")
	assert_eq(back.expires_at, 123)
	assert_eq(back.user_id, "u")
	assert_null(SupabaseSession.from_dict({"access_token": "a"}), "incomplete data is rejected")
