extends GutTest
## Email sign-in with a 6-digit code (platform B6, PRD-AUTH-01): validation, resend cooldown,
## result mapping, session + login_* / email_* analytics through AuthService, and no PII in
## analytics. HTTP is a fake.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_email_session.cfg"
const NOW := 1_700_000_000
const EMAIL := "player@example.com"
const CODE := "482913"

var _http: FakeHttp
var _auth: AuthService
var _now_ms: int = 0
var _tracked: Array = []
var _signals: Array = []
var _results: Array[String] = []


func before_each() -> void:
	_http = FakeHttp.new()
	var client := SupabaseClient.new("https://proj.supabase.co", "anon", _http)
	client.now_s = func() -> int: return NOW
	client.net_error_sink = func(_e: String, _s: int) -> void: pass
	_now_ms = 0
	_tracked.clear()
	_signals.clear()
	_results.clear()
	_auth = AuthService.new()
	_auth.platform_kind = "mobile"
	_auth.track = func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	_auth.identify = func(u: String) -> void: _signals.append(["identify", u])
	_auth.setup(client, SessionStore.new(STORE_PATH), 54321, "")
	_auth.email.clock_ms = func() -> int: return _now_ms
	_auth.signed_in.connect(func(s: SupabaseSession) -> void: _signals.append(["in", s.user_id]))
	_auth.sign_in_failed.connect(func(r: String) -> void: _signals.append(["failed", r]))


func after_each() -> void:
	_auth.free()
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _done() -> Callable:
	return func(result: String) -> void: _results.append(result)


func _names() -> Array[String]:
	var out: Array[String] = []
	for t: Array in _tracked:
		out.append(String(t[0]))
	return out


func _props(event_name: String) -> Array:
	var out: Array = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


func _send_ok() -> void:
	_auth.send_email_code(EMAIL, _done())
	_http.respond(200, "{}")


func _token_json() -> String:
	return JSON.stringify({"access_token": "a", "refresh_token": "r", "expires_in": 3600, "user": {"id": "user-7"}})


func test_email_validation() -> void:
	for good: String in ["a@b.co", "first.last+tag@sub.example.kr", "  Mixed@Example.COM "]:
		assert_true(EmailOtp.is_valid_email(good), good)
	for bad: String in ["", "plain", "a@b", "@b.co", "a@.co", "a b@c.co", "a@@b.co", "a@b.co@c.co"]:
		assert_false(EmailOtp.is_valid_email(bad), bad)
	assert_false(EmailOtp.is_valid_email("x".repeat(250) + "@b.co"), "longer than an address can be")
	assert_eq(EmailOtp.normalize("  Mixed@Example.COM "), "mixed@example.com")


func test_code_validation() -> void:
	assert_true(EmailOtp.is_valid_code("012345"))
	for bad: String in ["", "12345", "1234567", "12345a", "12 345"]:
		assert_false(EmailOtp.is_valid_code(bad), bad)


func test_invalid_email_is_refused_without_a_request() -> void:
	_auth.send_email_code("not-an-email", _done())
	assert_eq(_results, ["invalid_email"])
	assert_eq(_http.requests.size(), 0)
	assert_eq(_props("email_code_requested"), [{"result": "invalid_email"}])


func test_send_normalizes_and_starts_the_cooldown() -> void:
	_auth.send_email_code("  Player@Example.com ", _done())
	assert_eq((_http.last_json() as Dictionary)["email"], EMAIL)
	assert_eq(_auth.email.cooldown_left_s(), 0, "no cooldown until the mail is on its way")
	_http.respond(200, "{}")
	assert_eq(_results, ["ok"])
	assert_eq(_names(), ["login_started", "email_code_requested"])
	assert_eq(_props("login_started")[0], {"provider": "email", "platform": "mobile"})
	assert_eq(_auth.email.cooldown_left_s(), EmailOtp.RESEND_COOLDOWN_S)
	_now_ms = 59_500
	assert_eq(_auth.email.cooldown_left_s(), 1, "rounded up")
	_now_ms = 60_000
	assert_eq(_auth.email.cooldown_left_s(), 0)


func test_resend_waits_for_the_cooldown() -> void:
	_send_ok()
	_now_ms = 10_000
	_auth.send_email_code(EMAIL, _done())
	assert_eq(_results, ["ok", "rate_limited"])
	assert_eq(_http.requests.size(), 1, "no request while cooling down")
	_now_ms = 61_000
	_auth.send_email_code(EMAIL, _done())
	_http.respond(200, "{}")
	assert_eq(_results.back(), "ok")
	assert_eq(_names().count("login_started"), 1, "a resend is the same attempt")
	assert_eq(_names().count("email_code_resent"), 1, "only resends that reach the server")


func test_a_different_email_is_not_a_resend() -> void:
	_send_ok()
	_auth.send_email_code("other@example.com", _done())
	assert_eq(_http.requests.size(), 2, "the cooldown belongs to the first address")
	_http.respond(200, "{}")
	assert_eq(_names().count("login_started"), 2)
	assert_false(_names().has("email_code_resent"))


func test_send_results_are_mapped() -> void:
	var cases := [[429, "{}", "rate_limited"], [422, "{\"error_code\":\"validation_failed\"}", "invalid_email"],
		[400, "{\"error_code\":\"email_address_invalid\"}", "invalid_email"],
		[400, "{\"error_code\":\"email_provider_disabled\"}", "error"],
		[400, "{\"error_code\":\"email_address_not_authorized\"}", "error"], [500, "", "error"], [0, "", "error"]]
	for i: int in cases.size():
		var c: Array = cases[i]
		_auth.send_email_code("p%d@example.com" % i, _done())
		_http.respond(int(c[0]), String(c[1]))
		assert_eq(_results.back(), String(c[2]), "status %d %s" % [c[0], c[1]])
	assert_eq(_props("login_failed")[0], {"provider": "email", "reason": "send_rate_limited"})


func test_rate_limited_send_also_starts_the_cooldown() -> void:
	_auth.send_email_code(EMAIL, _done())
	_http.respond(429, "{}")
	assert_eq(_auth.email.cooldown_left_s(), EmailOtp.RESEND_COOLDOWN_S)


func test_verify_signs_in_and_tracks_attempts() -> void:
	_send_ok()
	_auth.verify_email_code(EMAIL, "000000", _done())
	_http.respond(403, "{\"error_code\":\"otp_expired\"}")
	assert_eq(_results.back(), "wrong_code")
	assert_eq(_props("login_failed").back(), {"provider": "email", "reason": "verify_wrong_code"})
	assert_false(_signals.has(["failed", "wrong_code"]), "a wrong code is not a failed sign-in signal")
	_auth.verify_email_code(EMAIL, CODE, _done())
	assert_eq(_http.last_json(), {"type": "email", "email": EMAIL, "token": CODE})
	_http.respond(200, _token_json())
	assert_eq(_results.back(), "ok")
	assert_eq(_props("email_code_verified"), [{"attempts": 2}])
	assert_eq(_props("login_completed"), [{"provider": "email", "platform": "mobile"}])
	assert_true(_signals.has(["in", "user-7"]))
	assert_true(_signals.has(["identify", "user-7"]))
	assert_eq(SessionStore.new(STORE_PATH).load_session().user_id, "user-7", "the session is saved")


func test_verify_refuses_a_malformed_code_without_a_request() -> void:
	_send_ok()
	_auth.verify_email_code(EMAIL, "12a4", _done())
	assert_eq(_results.back(), "invalid_code")
	assert_eq(_http.requests.size(), 1)


func test_verify_errors_are_mapped() -> void:
	_send_ok()
	for c: Array in [[400, "wrong_code"], [429, "rate_limited"], [500, "error"], [0, "error"]]:
		_auth.verify_email_code(EMAIL, CODE, _done())
		_http.respond(int(c[0]), "{}")
		assert_eq(_results.back(), String(c[1]), "status %d" % c[0])


func test_a_new_code_resets_the_attempts() -> void:
	_send_ok()
	_auth.verify_email_code(EMAIL, "000000", _done())
	_http.respond(403, "{}")
	_now_ms = 61_000
	_send_ok()
	_auth.verify_email_code(EMAIL, CODE, _done())
	_http.respond(200, _token_json())
	assert_eq(_props("email_code_verified"), [{"attempts": 1}])


func test_one_request_at_a_time() -> void:
	_auth.send_email_code(EMAIL, _done())
	_auth.send_email_code(EMAIL, _done())
	assert_eq(_http.requests.size(), 1)
	assert_eq(_results, ["busy"])


func test_email_events_are_in_the_catalog_and_valid() -> void:
	_send_ok()
	_now_ms = 61_000
	_send_ok()
	_auth.verify_email_code(EMAIL, CODE, _done())
	_http.respond(200, _token_json())
	for t: Array in _tracked:
		assert_eq(EventCatalog.validate(String(t[0]), t[1]).size(), 0, "%s %s" % [t[0], t[1]])


func test_no_email_or_code_reaches_analytics() -> void:
	_auth.send_email_code("bad@", _done())
	_send_ok()
	_auth.verify_email_code(EMAIL, "000000", _done())
	_http.respond(403, "{}")
	_now_ms = 61_000
	_send_ok()
	_auth.verify_email_code(EMAIL, CODE, _done())
	_http.respond(200, _token_json())
	assert_gt(_tracked.size(), 6)
	for t: Array in _tracked:
		var text := JSON.stringify(t[1])
		assert_false(text.contains("@"), "%s carries an email: %s" % [t[0], text])
		assert_false(text.contains(CODE) or text.contains("000000"), "%s carries a code: %s" % [t[0], text])
		assert_false(text.contains("example"), "%s carries part of the address" % t[0])
