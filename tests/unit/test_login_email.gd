extends GutTest
## Email mode of the login card (design.md DS-CMP-14, platform B6): the ghost "이메일로 계속하기"
## button, email step → code step, cooldown, Enter/Esc, messages, and the login screen driving a
## LoginGate on a fake Supabase (no network).

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const LOGIN_PANEL := preload("res://src/ui/components/login_panel/login_panel.tscn")
const STORE_PATH := "user://test_login_email_session.cfg"
const NOW := 1_700_000_000
const EMAIL := "player@example.com"

var _http: FakeHttp
var _signals: Array[String] = []


func after_each() -> void:
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _panel() -> LoginPanel:
	var p := LOGIN_PANEL.instantiate() as LoginPanel
	add_child_autofree(p)
	return p


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


func _esc(view: EmailLoginView) -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	view._input(ev)


func test_card_offers_email_under_google() -> void:
	var p := _panel()
	var b := p.email_button()
	assert_eq(b.text, "이메일로 계속하기")
	assert_eq(b.kind, UiMenuButton.Kind.GHOST)
	assert_gt(b.get_index(), p.google_button().get_index(), "under the Google button")
	assert_eq(p.mode(), LoginPanel.Mode.METHODS)
	assert_false(p.email_view().visible)


func test_email_button_switches_the_card() -> void:
	var p := _panel()
	p.email_button().pressed.emit()
	assert_eq(p.mode(), LoginPanel.Mode.EMAIL)
	assert_true(p.email_view().visible)
	assert_false(p.google_button().is_visible_in_tree(), "the same card, other content")
	var v := p.email_view()
	assert_eq(v.step(), EmailLoginView.Step.EMAIL)
	assert_true(v.email_field().visible)
	assert_false(v.code_input().visible)
	assert_eq(v.submit_button().text, "인증코드 받기")
	assert_eq(v.email_field().virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	v.back_button().pressed.emit()
	assert_eq(p.mode(), LoginPanel.Mode.METHODS)
	assert_true(p.google_button().is_visible_in_tree())


func test_email_step_submits_on_button_and_enter() -> void:
	var p := _panel()
	p.show_email()
	watch_signals(p)
	var v := p.email_view()
	v.email_field().text = "  " + EMAIL + " "
	v.submit_button().pressed.emit()
	assert_signal_emitted_with_parameters(p, "email_code_requested", [EMAIL])
	v.email_field().text_submitted.emit(EMAIL)
	assert_signal_emit_count(p, "email_code_requested", 2)


func test_code_step_and_resend_cooldown() -> void:
	var p := _panel()
	p.show_email()
	var v := p.email_view()
	v.email_field().text = EMAIL
	v.show_step(EmailLoginView.Step.CODE)
	assert_true(v.code_input().visible)
	assert_false(v.email_field().visible)
	assert_eq(v.submit_button().text, "로그인")
	assert_string_contains(v.helper_text(), EMAIL, "where the code went")
	v.set_cooldown(42)
	assert_eq(v.resend_button().text, "코드 다시 받기 (42초)")
	assert_true(v.resend_button().disabled)
	v.set_cooldown(0)
	assert_eq(v.resend_button().text, "코드 다시 받기")
	assert_false(v.resend_button().disabled)
	watch_signals(p)
	v.resend_button().pressed.emit()
	assert_signal_emitted_with_parameters(p, "email_resend_requested", [EMAIL])
	v.code_input().set_code("123456")
	v.code_input().submitted.emit("123456")
	assert_signal_emitted_with_parameters(p, "email_code_submitted", [EMAIL, "123456"])


func test_esc_steps_back() -> void:
	var p := _panel()
	p.show_email()
	var v := p.email_view()
	v.show_step(EmailLoginView.Step.CODE)
	_esc(v)
	assert_eq(v.step(), EmailLoginView.Step.EMAIL, "code → email (fix a typo)")
	_esc(v)
	assert_eq(p.mode(), LoginPanel.Mode.METHODS, "email → the other methods")


func test_busy_and_error_states() -> void:
	var p := _panel()
	p.show_email()
	var v := p.email_view()
	v.set_busy(true)
	assert_true(v.submit_button().disabled)
	assert_eq(v.submit_button().text, "보내는 중…")
	v.set_busy(false)
	v.set_message("잘못된 이메일이에요", true)
	assert_eq(v.message_text(), "잘못된 이메일이에요")
	assert_eq(v.email_field().state(), UiTextField.State.ERROR)
	v.show_step(EmailLoginView.Step.CODE)
	assert_eq(v.message_text(), "", "a new step starts clean")
	v.set_message("x", true)
	assert_eq(v.code_input().state(), CodeInput.State.ERROR)


func test_email_mode_follows_the_language() -> void:
	var p := _panel()
	p.toggle_language()
	assert_eq(p.email_button().text, "Continue with email")
	p.show_email()
	assert_eq(p.email_view().submit_button().text, "Send code")


func test_email_can_be_disabled() -> void:
	var p := _panel()
	p.set_email_enabled(false)
	assert_true(p.email_button().disabled)


func test_screen_sends_verifies_and_signs_in() -> void:
	var gate := _gate(true)
	var screen := _screen(gate)
	var v := screen.panel().email_view()
	screen.panel().email_button().pressed.emit()
	v.email_field().text = EMAIL
	v.submit_button().pressed.emit()
	assert_true(v.submit_button().disabled, "busy while the mail goes out")
	assert_string_contains(String(_http.last()["url"]), "/auth/v1/otp")
	_http.respond(200, "{}")
	assert_eq(v.step(), EmailLoginView.Step.CODE)
	assert_eq(v.message_text(), LoginMessages.CODE_SENT)
	screen._process(0.0)
	assert_eq(v.resend_button().text, "코드 다시 받기 (60초)")
	v.code_input().set_code("000000")
	v.submit_button().pressed.emit()
	_http.respond(403, "{}")
	assert_eq(v.message_text(), LoginMessages.WRONG_CODE)
	assert_eq(v.code_input().code(), "", "cleared for the next try")
	v.code_input().set_code("482913")
	v.submit_button().pressed.emit()
	_http.respond(200, JSON.stringify({"access_token": "a", "refresh_token": "r", "expires_in": 3600,
		"user": {"id": "user-7"}}))
	assert_eq(_signals, ["in"])


func test_screen_explains_a_bad_address_without_a_request() -> void:
	var gate := _gate(true)
	var screen := _screen(gate)
	var v := screen.panel().email_view()
	screen.panel().show_email()
	v.email_field().text = "nope"
	v.submit_button().pressed.emit()
	assert_eq(_http.requests.size(), 0)
	assert_eq(v.message_text(), LoginMessages.INVALID_EMAIL)
	assert_eq(v.step(), EmailLoginView.Step.EMAIL)


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
