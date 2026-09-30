extends GutTest
## Sign-in orchestration (platform A4): session restore/refresh, desktop loopback, web redirect,
## mobile refusal and login_* analytics. Loopback, browser and HTTP are all fakes.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_session.cfg"
const NOW := 1_700_000_000
const URL := "https://proj.supabase.co"


class FakeLoopback extends LoopbackServer:
	var started_port: int = -1
	var result: Dictionary = {}

	func start(port: int, _now_ms: int) -> Error:
		started_port = port
		return OK

	func poll(_now_ms: int) -> Dictionary:
		return result

	func stop() -> void:
		started_port = -1


class FakeWeb extends WebCallback:
	var query: Dictionary = {}
	var redirected: String = ""
	var cleaned: bool = false

	func read_query() -> Dictionary:
		return query

	func clean_url() -> void:
		cleaned = true

	func redirect(url: String) -> void:
		redirected = url

	func current_url() -> String:
		return "https://game.example/"


var _http: FakeHttp
var _client: SupabaseClient
var _store: SessionStore
var _auth: AuthService
var _loop: FakeLoopback
var _web: FakeWeb
var _opened: Array[String] = []
var _tracked: Array = []
var _signals: Array = []


func before_each() -> void:
	_http = FakeHttp.new()
	_client = SupabaseClient.new(URL, "anon", _http)
	_client.now_s = func() -> int: return NOW
	_client.net_error_sink = func(_e: String, _s: int) -> void: pass
	_store = SessionStore.new(STORE_PATH)
	_loop = FakeLoopback.new()
	_web = FakeWeb.new()
	_opened.clear()
	_tracked.clear()
	_signals.clear()
	_auth = AuthService.new()
	_auth.loopback = _loop
	_auth.web = _web
	_auth.open_url = func(u: String) -> Error:
		_opened.append(u)
		return OK
	_auth.track = func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	_auth.clock_ms = func() -> int: return 0
	_auth.setup(_client, _store, 54321, "https://game.example/play")
	_auth.signed_in.connect(func(s: SupabaseSession) -> void: _signals.append(["in", s.user_id]))
	_auth.sign_in_failed.connect(func(r: String) -> void: _signals.append(["failed", r]))
	_auth.signed_out.connect(func() -> void: _signals.append(["out"]))


func after_each() -> void:
	_auth.free()
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _names() -> Array[String]:
	var out: Array[String] = []
	for t: Array in _tracked:
		out.append(String(t[0]))
	return out


func _token_json(access: String, refresh: String) -> String:
	return JSON.stringify({"access_token": access, "refresh_token": refresh, "expires_in": 3600,
		"user": {"id": "user-7"}})


func test_store_round_trip_and_verifier_taken_once() -> void:
	_store.save(SupabaseSession.new("a", "r", 99, "u"))
	var back := SessionStore.new(STORE_PATH).load_session()
	assert_eq(back.refresh_token, "r")
	assert_eq(back.expires_at, 99)
	_store.save_verifier("ver")
	assert_eq(_store.take_verifier(), "ver")
	assert_eq(_store.take_verifier(), "", "single use")
	assert_not_null(_store.load_session(), "taking the verifier keeps the session")
	_store.clear()
	assert_null(_store.load_session())


func test_restore_without_session_does_nothing() -> void:
	platform("desktop")
	assert_false(_auth.restore())
	assert_eq(_http.requests.size(), 0)
	assert_eq(_signals.size(), 0)


func test_restore_valid_session_signs_in_without_network() -> void:
	platform("desktop")
	_store.save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	assert_true(_auth.restore())
	assert_eq(_http.requests.size(), 0)
	assert_eq(_signals, [["in", "user-7"]])
	assert_true(_auth.is_signed_in())
	assert_true(_names().has("session_restored"))


func test_restore_refreshes_an_expiring_session() -> void:
	platform("desktop")
	_store.save(SupabaseSession.new("a", "r", NOW, "user-7"))
	assert_true(_auth.restore())
	assert_string_contains(String(_http.last()["url"]), "grant_type=refresh_token")
	_http.respond(200, _token_json("a2", "r2"))
	assert_eq(_signals, [["in", "user-7"]])
	assert_eq(_store.load_session().refresh_token, "r2", "the rotated refresh token is saved")


func test_rejected_refresh_signs_out_and_forgets() -> void:
	platform("desktop")
	_store.save(SupabaseSession.new("a", "r", NOW, "user-7"))
	_auth.restore()
	_http.respond(400, "{}")
	assert_eq(_signals, [["out"]])
	assert_null(_store.load_session())


func test_desktop_sign_in_via_loopback() -> void:
	platform("desktop")
	_auth.sign_in()
	assert_eq(_names(), ["login_started"])
	assert_eq(_loop.started_port, 54321)
	assert_eq(_opened.size(), 1)
	var url := _opened[0]
	assert_string_contains(url, URL + "/auth/v1/authorize?provider=google")
	assert_string_contains(url, "redirect_to=http%3A%2F%2F127.0.0.1%3A54321%2Fcallback%3Fstate%3D")
	var nonce := _loop.expected_state()
	assert_eq(nonce.length(), AuthUrls.STATE_LENGTH, "the loopback waits for this sign-in's nonce")
	assert_string_contains(url, "state%3D" + nonce)
	_auth.poll()
	assert_eq(_http.requests.size(), 0, "waiting for the browser")
	_loop.result = {"code": "code-1"}
	_auth.poll()
	var body: Dictionary = _http.last_json()
	assert_eq(body["auth_code"], "code-1")
	var challenge := url.get_slice("code_challenge=", 1).get_slice("&", 0)
	assert_eq(Pkce.challenge(String(body["code_verifier"])), challenge, "the verifier matches the challenge")
	_http.respond(200, _token_json("a", "r"))
	assert_eq(_signals, [["in", "user-7"]])
	assert_eq(_names(), ["login_started", "login_completed"])
	assert_eq(_store.load_session().user_id, "user-7")


func test_desktop_timeout_fails_with_reason() -> void:
	platform("desktop")
	_auth.sign_in()
	_loop.result = {"error": "timeout"}
	_auth.poll()
	assert_eq(_signals, [["failed", "timeout"]])
	assert_eq(_names(), ["login_started", "login_failed"])
	assert_eq(_tracked[1][1]["reason"], "timeout")


func test_failed_exchange_reports_status() -> void:
	platform("desktop")
	_auth.sign_in()
	_loop.result = {"code": "c"}
	_auth.poll()
	_http.respond(400, "{}")
	assert_eq(_signals, [["failed", "exchange_400"]])


func test_mobile_is_not_supported() -> void:
	platform("mobile")
	_auth.sign_in()
	assert_eq(_signals, [["failed", "mobile_unsupported"]])
	assert_eq(_opened.size(), 0)
	assert_eq(_names(), ["login_started", "login_failed"])


func test_web_sign_in_redirects_and_resumes() -> void:
	platform("web")
	_auth.sign_in()
	assert_string_contains(_web.redirected, "redirect_to=https%3A%2F%2Fgame.example%2Fplay")
	assert_ne(_store.peek_verifier(), "", "verifier survives the page reload")
	_web.query = {"code": "web-code"}
	assert_true(_auth.restore())
	assert_true(_web.cleaned, "the code is removed from the address bar")
	assert_eq((_http.last_json() as Dictionary)["auth_code"], "web-code")
	_http.respond(200, _token_json("a", "r"))
	assert_eq(_signals, [["in", "user-7"]])


func test_web_callback_error_is_reported() -> void:
	platform("web")
	_store.save_verifier("v")
	_web.query = {"error": "access_denied"}
	assert_true(_auth.restore())
	assert_eq(_signals, [["failed", "access_denied"]])
	assert_true(_web.cleaned)
	assert_eq(_store.peek_verifier(), "", "the attempt is over")


func test_web_query_without_our_sign_in_is_ignored() -> void:
	platform("web")
	_web.query = {"code": "someone-elses"}
	assert_false(_auth.restore())
	assert_false(_web.cleaned)
	assert_eq(_http.requests.size(), 0)


func test_offline_refresh_fails_but_keeps_the_stored_session() -> void:
	platform("desktop")
	_store.save(SupabaseSession.new("a", "r", NOW, "user-7"))
	_auth.restore()
	_http.respond(0, "")
	assert_eq(_signals, [["failed", "refresh_0"]])
	assert_false(_auth.is_signed_in())
	assert_not_null(_store.load_session(), "try again next start")


func test_sign_out_forgets_the_session() -> void:
	platform("desktop")
	_store.save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	_auth.restore()
	_auth.sign_out()
	assert_false(_auth.is_signed_in())
	assert_null(_store.load_session())
	assert_true(_names().has("logout"))


func platform(kind: String) -> void:
	_auth.platform_kind = kind
