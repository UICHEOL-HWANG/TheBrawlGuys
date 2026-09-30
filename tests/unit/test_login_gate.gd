extends GutTest
## LoginGate (platform B1): the app's view of sign-in — availability, session restore, sign-in,
## sign-out and the login analytics the shell owns. AuthService runs on fakes (no network).

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_gate_session.cfg"
const NOW := 1_700_000_000

var _tracked: Array = []
var _signals: Array = []


func after_each() -> void:
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _gate(with_auth: bool, kind: String = "desktop") -> LoginGate:
	_tracked.clear()
	_signals.clear()
	var gate := LoginGate.new()
	gate.platform_kind = kind
	gate.track = func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	if with_auth:
		var client := SupabaseClient.new("https://proj.supabase.co", "anon", FakeHttp.new())
		client.now_s = func() -> int: return NOW
		var auth := AuthService.new()
		auth.platform_kind = kind
		auth.track = gate.track
		auth.identify = func(_u: String) -> void: pass
		auth.open_url = func(_u: String) -> Error: return OK
		auth.setup(client, SessionStore.new(STORE_PATH), 54321, "")
		gate.use_auth(auth)
	add_child_autofree(gate)
	gate.signed_in.connect(func() -> void: _signals.append("in"))
	gate.failed.connect(func(r: String) -> void: _signals.append("failed:" + r))
	gate.signed_out.connect(func() -> void: _signals.append("out"))
	return gate


func _names() -> Array[String]:
	var out: Array[String] = []
	for t: Array in _tracked:
		out.append(String(t[0]))
	return out


func test_missing_keys_make_sign_in_unavailable() -> void:
	var gate := _gate(false)
	assert_eq(gate.availability(), LoginGate.REASON_NOT_CONFIGURED)
	assert_false(gate.restore())
	gate.sign_in()
	assert_eq(_names(), ["login_started", "login_failed"])
	assert_eq(_tracked[1][1]["reason"], LoginGate.REASON_NOT_CONFIGURED)
	assert_eq(_signals, ["failed:" + LoginGate.REASON_NOT_CONFIGURED])


func test_mobile_is_unavailable_even_with_keys() -> void:
	var gate := _gate(true, "mobile")
	assert_eq(gate.availability(), LoginGate.REASON_MOBILE)


func test_desktop_with_keys_is_available() -> void:
	var gate := _gate(true)
	assert_eq(gate.availability(), "")
	gate.sign_in()
	assert_eq(_names(), ["login_started"], "AuthService tracks the rest")


func test_restore_signs_in_from_a_stored_session() -> void:
	SessionStore.new(STORE_PATH).save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	var gate := _gate(true)
	assert_true(gate.restore())
	assert_eq(_signals, ["in"])
	assert_true(gate.is_signed_in())
	assert_true(_names().has("session_restored"))


func test_skip_is_offered_only_when_unavailable_in_debug() -> void:
	assert_true(_gate(false).can_skip(), "tests run a debug build")
	assert_false(_gate(true).can_skip())


func test_skip_tracks_login_skipped() -> void:
	var gate := _gate(false)
	gate.skip()
	assert_eq(_names(), ["login_skipped"])


func test_sign_out_without_auth_still_tracks_and_signals() -> void:
	var gate := _gate(false)
	gate.sign_out()
	assert_eq(_names(), ["logout"])
	assert_eq(_signals, ["out"])


func test_sign_out_with_auth_forgets_the_session() -> void:
	SessionStore.new(STORE_PATH).save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	var gate := _gate(true)
	gate.restore()
	_signals.clear()
	gate.sign_out()
	assert_false(gate.is_signed_in())
	assert_eq(_signals, ["out"], "one signed_out, not two")
	assert_true(_names().has("logout"))
