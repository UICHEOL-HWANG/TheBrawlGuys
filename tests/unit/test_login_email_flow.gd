extends GutTest
## LoginEmailFlow (platform B6): the login screen driving the card's email mode through a
## LoginGate on a fake Supabase — send, verify, messages, rings, focus, same-address re-entry,
## Esc while busy and late answers after the screen is gone. No network.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_login_email_flow.cfg"
const NOW := 1_700_000_000
const EMAIL := "player@example.com"

var _http: FakeHttp
var _signals: Array[String] = []


func after_each() -> void:
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _gate(with_auth: bool, kind: String = "desktop") -> LoginGate:
	_signals.clear()
	var gate := LoginGate.new()
	gate.platform_kind = kind
	gate.track = func(_n: String, _p: Dictionary) -> void: pass
	if with_auth:
		_http = FakeHttp.new()
		var client := SupabaseClient.new("https://proj.supabase.co", "anon", _http)
		client.now_s = func() -> int: return NOW
		client.net_error_sink = func(_e: String, _s: int) -> void: pass
		var auth := AuthService.new()
		auth.platform_kind = kind
		auth.track = gate.track
		auth.identify = func(_u: String) -> void: pass
		auth.setup(client, SessionStore.new(STORE_PATH), 54321, "")
		gate.use_auth(auth)
	add_child_autofree(gate)
	gate.signed_in.connect(func() -> void: _signals.append("in"))
	return gate


func _screen(gate: LoginGate) -> LoginScreen:
	var screen := LoginScreen.new()
	screen.track = gate.track
	screen.setup(gate, false)
	add_child_autofree(screen)
	return screen


## Email mode open with the address typed.
func _email_view(screen: LoginScreen) -> EmailLoginView:
	screen.panel().email_button().pressed.emit()
	var v := screen.panel().email_view()
	v.email_field().text = EMAIL
	return v


func _code_step(screen: LoginScreen) -> EmailLoginView:
	var v := _email_view(screen)
	v.submit_button().pressed.emit()
	_http.respond(200, "{}")
	return v


func _esc(view: EmailLoginView) -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	view._input(ev)


func test_screen_sends_verifies_and_signs_in() -> void:
	var screen := _screen(_gate(true))
	var v := _email_view(screen)
	v.submit_button().pressed.emit()
	assert_true(v.submit_button().disabled, "busy while the mail goes out")
	assert_string_contains(String(_http.last()["url"]), "/auth/v1/otp")
	_http.respond(200, "{}")
	assert_eq(v.step(), EmailLoginView.Step.CODE)
	assert_eq(v.message_text(), LoginMessages.CODE_SENT)
	screen._process(0.0)
	assert_eq(v.resend_button().text, "코드 다시 받기 (60초)")
	v.code_input().set_code("482913")
	v.submit_button().pressed.emit()
	_http.respond(200, JSON.stringify({"access_token": "a", "refresh_token": "r", "expires_in": 3600,
		"user": {"id": "user-7"}}))
	assert_eq(_signals, ["in"])


func test_wrong_code_clears_rings_and_refocuses() -> void:
	var screen := _screen(_gate(true))
	var v := _code_step(screen)
	v.code_input().set_code("000000")
	v.submit_button().grab_focus()
	v.submit_button().pressed.emit()
	_http.respond(403, "{\"error_code\":\"otp_expired\"}")
	assert_eq(v.message_text(), LoginMessages.WRONG_CODE)
	assert_eq(v.code_input().code(), "", "cleared for the next try")
	assert_eq(v.code_input().state(), CodeInput.State.ERROR, "the ring stays until they type")
	await wait_process_frames(1)
	assert_true(v.code_input().field().has_focus(), "back in the boxes")


func test_screen_explains_a_bad_address_without_a_request() -> void:
	var screen := _screen(_gate(true))
	var v := _email_view(screen)
	v.email_field().text = "nope"
	v.submit_button().pressed.emit()
	assert_eq(_http.requests.size(), 0)
	assert_eq(v.message_text(), LoginMessages.INVALID_EMAIL)
	assert_eq(v.step(), EmailLoginView.Step.EMAIL)


func test_same_address_again_goes_back_to_the_code() -> void:
	var screen := _screen(_gate(true))
	var v := _code_step(screen)
	_esc(v)
	assert_eq(v.step(), EmailLoginView.Step.EMAIL)
	v.submit_button().pressed.emit()
	assert_eq(_http.requests.size(), 1, "still cooling down: no new mail")
	assert_eq(v.step(), EmailLoginView.Step.CODE, "the mailed code still works")
	assert_eq(v.message_text(), LoginMessages.CODE_ALREADY_SENT)


func test_resend_clears_the_old_code() -> void:
	var gate := _gate(true)
	var screen := _screen(gate)
	var v := _code_step(screen)
	v.code_input().set_code("12")
	gate.auth.email.clock_ms = func() -> int: return Time.get_ticks_msec() + 61_000
	screen._process(0.0)
	v.resend_button().pressed.emit()
	_http.respond(200, "{}")
	assert_eq(v.code_input().code(), "")
	assert_eq(v.message_text(), LoginMessages.CODE_SENT)


func test_esc_waits_while_a_request_is_out() -> void:
	var screen := _screen(_gate(true))
	var v := _code_step(screen)
	v.code_input().set_code("000000")
	v.submit_button().pressed.emit()
	_esc(v)
	assert_eq(v.step(), EmailLoginView.Step.CODE, "no stepping back mid-request")
	_http.respond(403, "{}")
	assert_eq(v.code_input().state(), CodeInput.State.ERROR)
	assert_ne(v.email_field().state(), UiTextField.State.ERROR)


func test_late_answer_after_the_screen_is_gone() -> void:
	var screen := _screen(_gate(true))
	var v := _email_view(screen)
	v.submit_button().pressed.emit()
	screen.free()
	_http.respond(200, "{}")
	assert_true(true, "no error from the freed view")


func test_mobile_keeps_email_while_google_waits() -> void:
	var screen := _screen(_gate(true, "mobile"))
	assert_true(screen.panel().google_button().disabled)
	assert_false(screen.panel().email_button().disabled, "email works on mobile")
	assert_eq(screen.panel().message_text(), LoginMessages.MOBILE)


func test_email_is_off_without_keys() -> void:
	var gate := _gate(false)
	var screen := _screen(gate)
	assert_true(screen.panel().email_button().disabled)
	assert_eq(gate.email_availability(), LoginGate.REASON_NOT_CONFIGURED)
	var results: Array[String] = []
	gate.send_email_code(EMAIL, func(r: String) -> void: results.append(r))
	assert_eq(results, [LoginGate.REASON_NOT_CONFIGURED])
