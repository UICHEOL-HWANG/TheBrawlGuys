class_name LoginEmailFlow
extends RefCounted
## Drives the login card's email mode from a LoginGate (platform B6, PRD-AUTH-01): sends the code
## and moves to the code step, verifies it, keeps "코드 다시 받기 (N초)" current and explains every
## other result in one line (LoginMessages). A good code signs in through the gate's signed_in,
## which the app shell handles (it leaves this screen). Answers hold the view and gate weakly:
## one that arrives after the screen is gone is dropped.

## Results that point at what the player typed: the input rings red until they type again.
const INPUT_ERRORS: Array[String] = [
	EmailOtp.RESULT_INVALID_EMAIL, EmailOtp.RESULT_INVALID_CODE, EmailOtp.RESULT_WRONG_CODE,
]

var _panel: LoginPanel
var _gate: LoginGate


func _init(panel: LoginPanel, gate: LoginGate) -> void:
	_panel = panel
	_gate = gate
	panel.email_code_requested.connect(_send)
	panel.email_resend_requested.connect(_send)
	panel.email_code_submitted.connect(_verify)


## Call every frame while the screen shows.
func tick() -> void:
	_panel.email_view().set_cooldown(_gate.email_cooldown_s())


func _send(address: String) -> void:
	var view_ref: WeakRef = weakref(_panel.email_view())
	var gate_ref: WeakRef = weakref(_gate)
	_panel.email_view().set_busy(true)
	_gate.send_email_code(address, func(result: String) -> void:
		var view := view_ref.get_ref() as EmailLoginView
		var gate := gate_ref.get_ref() as LoginGate
		if view != null and gate != null and result != EmailOtp.RESULT_BUSY:
			LoginEmailFlow._on_sent(view, gate, address, result))


func _verify(address: String, code: String) -> void:
	var view_ref: WeakRef = weakref(_panel.email_view())
	_panel.email_view().set_busy(true)
	_gate.verify_email_code(address, code, func(result: String) -> void:
		var view := view_ref.get_ref() as EmailLoginView
		# RESULT_OK: signed in, the view stays "확인 중…" while the app moves on.
		if view != null and result != EmailOtp.RESULT_BUSY and result != EmailOtp.RESULT_OK:
			LoginEmailFlow._on_verify_failed(view, result))


static func _on_sent(view: EmailLoginView, gate: LoginGate, address: String, result: String) -> void:
	view.set_busy(false)
	var back_to_code := view.step() == EmailLoginView.Step.EMAIL and gate.email_code_pending(address)
	if result == EmailOtp.RESULT_OK:
		view.code_input().clear()  # a fresh code: the old digits and ring go
		_show_code(view, LoginMessages.CODE_SENT)
	elif result == EmailOtp.RESULT_RATE_LIMITED and back_to_code:
		_show_code(view, LoginMessages.CODE_ALREADY_SENT)  # same address again: its mail is out
	else:
		_explain(view, result)
	view.set_cooldown(gate.email_cooldown_s())


static func _on_verify_failed(view: EmailLoginView, result: String) -> void:
	view.set_busy(false)
	if result == EmailOtp.RESULT_WRONG_CODE:
		view.code_input().clear()  # before the message, so the red ring stays
	_explain(view, result)


static func _show_code(view: EmailLoginView, message: String) -> void:
	if view.step() != EmailLoginView.Step.CODE:
		view.show_step(EmailLoginView.Step.CODE)
	view.set_message(message, false)
	view.focus_current()


## One line; results about what was typed ring that input. Focus goes back to it either way.
static func _explain(view: EmailLoginView, result: String) -> void:
	view.set_message(LoginMessages.for_email(result), INPUT_ERRORS.has(result))
	view.focus_current()
