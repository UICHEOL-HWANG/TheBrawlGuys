extends GutTest
## Supabase email OTP endpoints (platform B6): /auth/v1/otp sends a 6-digit code, /auth/v1/verify
## turns it into a session exactly like the PKCE exchange. HTTP is a fake.

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


func _done() -> Callable:
	return func(ok: bool, status: int, message: String) -> void: _results.append([ok, status, message])


func test_send_posts_the_email_and_creates_users() -> void:
	_client.send_email_otp("a@b.co", _done())
	var r := _http.last()
	assert_eq(r["url"], URL + "/auth/v1/otp")
	assert_eq(r["method"], HTTPClient.METHOD_POST)
	assert_eq(_http.header(r, "apikey"), "anon-key")
	assert_eq(_http.header(r, "Content-Type"), "application/json")
	assert_eq(_http.last_json(), {"email": "a@b.co", "create_user": true})
	_http.respond(200, "{}")
	assert_eq(_results, [[true, 200, ""]])
	assert_false(_client.has_session(), "sending a code signs nobody in")


func test_send_failure_passes_the_status_and_body() -> void:
	_client.send_email_otp("a@b.co", _done())
	_http.respond(429, "{\"error_code\":\"over_email_send_rate_limit\"}")
	assert_false(_results[0][0])
	assert_eq(_results[0][1], 429)
	assert_string_contains(String(_results[0][2]), "over_email_send_rate_limit")
	assert_eq(_net_errors.size(), 0, "a player-side limit is not a network error")


func test_send_server_error_is_a_net_error() -> void:
	_client.send_email_otp("a@b.co", _done())
	_http.respond(0, "")
	_client.send_email_otp("a@b.co", _done())
	_http.respond(502, "")
	assert_eq(_net_errors, [["auth/otp", 0], ["auth/otp", 502]])


func test_verify_stores_the_session_like_the_exchange() -> void:
	var changed: Array = []
	_client.session_changed.connect(func(s: SupabaseSession) -> void: changed.append(s))
	_client.verify_email_otp("a@b.co", "123456", _done())
	var r := _http.last()
	assert_eq(r["url"], URL + "/auth/v1/verify")
	assert_eq(_http.header(r, "apikey"), "anon-key")
	assert_eq(_http.last_json(), {"type": "email", "email": "a@b.co", "token": "123456"})
	_http.respond(200, JSON.stringify({"access_token": "acc", "refresh_token": "ref", "expires_in": 3600,
		"user": {"id": "user-9"}}))
	assert_true(_results[0][0])
	assert_eq(_client.session.user_id, "user-9")
	assert_eq(_client.session.refresh_token, "ref")
	assert_eq(_client.session.expires_at, NOW + 3600)
	assert_eq(changed.size(), 1, "persisted through session_changed")


func test_wrong_code_fails_without_a_session_or_net_error() -> void:
	_client.verify_email_otp("a@b.co", "000000", _done())
	_http.respond(403, "{\"error_code\":\"otp_expired\"}")
	assert_false(_client.has_session())
	assert_eq(_results[0][1], 403)
	assert_eq(_net_errors.size(), 0)


func test_verify_malformed_success_is_an_error() -> void:
	_client.verify_email_otp("a@b.co", "123456", _done())
	_http.respond(200, "{\"user\":{}}")
	assert_false(_results[0][0])
	assert_false(_client.has_session())
