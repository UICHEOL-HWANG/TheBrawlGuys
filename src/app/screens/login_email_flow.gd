class_name LoginEmailFlow
extends RefCounted
## Drives the login card's email mode from a LoginGate (platform B6, PRD-AUTH-01): sends the code
## and moves to the code step, verifies it, keeps "코드 다시 받기 (N초)" current and explains every
## other result in one line (LoginMessages). A good code signs in through the gate's signed_in,
## which the app shell handles (it leaves this screen).

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
	var view := _panel.email_view()
	view.set_busy(true)
	_gate.send_email_code(address, func(result: String) -> void:
		if not is_instance_valid(view) or result == EmailOtp.RESULT_BUSY:
			return
		view.set_busy(false)
		if result == EmailOtp.RESULT_OK:
			if view.step() != EmailLoginView.Step.CODE:
				view.show_step(EmailLoginView.Step.CODE)
			view.set_message(LoginMessages.CODE_SENT, false)
		else:
			view.set_message(LoginMessages.for_email(result), INPUT_ERRORS.has(result))
		tick())


func _verify(address: String, code: String) -> void:
	var view := _panel.email_view()
	view.set_busy(true)
	_gate.verify_email_code(address, code, func(result: String) -> void:
		if not is_instance_valid(view) or result == EmailOtp.RESULT_BUSY:
			return
		if result == EmailOtp.RESULT_OK:
			return  # signed in: stays "확인 중…" while the app moves on
		view.set_busy(false)
		if result == EmailOtp.RESULT_WRONG_CODE:
			view.code_input().clear()  # before the message, so the red ring stays
		view.set_message(LoginMessages.for_email(result), INPUT_ERRORS.has(result)))
