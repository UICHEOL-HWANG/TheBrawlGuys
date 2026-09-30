class_name EmailOtp
extends RefCounted
## Passwordless email sign-in (platform B6, PRD-AUTH-01): Supabase mails a 6-digit code, the
## player types it in the game and gets a session; the account is created on first use. No
## redirect, so it works on desktop, web and mobile alike. Checks the address and the code before
## any request, keeps a resend cooldown for the last address, and maps HTTP outcomes to RESULT_*
## the login card explains. Analytics never carry the address or the code (tracking-plan T4).
## Callbacks: done(result: String).

const PROVIDER := "email"
const CODE_LENGTH := 6
const RESEND_COOLDOWN_S := 60
const MAX_EMAIL_LENGTH := 254
const RESULT_OK := "ok"
const RESULT_RATE_LIMITED := "rate_limited"
const RESULT_INVALID_EMAIL := "invalid_email"
const RESULT_INVALID_CODE := "invalid_code"
const RESULT_WRONG_CODE := "wrong_code"
const RESULT_ERROR := "error"
## A request is already out: nothing sent, nothing tracked.
const RESULT_BUSY := "busy"
const HTTP_TOO_MANY := 429
const HTTP_CLIENT_ERRORS := Vector2i(400, 499)
## 400/422 refusals caused by project settings or built-in SMTP limits, not by the address.
const SETUP_ERRORS: Array[String] = [
	"email_provider_disabled", "otp_disabled", "signup_disabled", "email_address_not_authorized",
]
const EMAIL_PATTERN := "^[^\\s@]+@[^\\s@.]+(\\.[^\\s@.]+)+$"
const CODE_PATTERN := "^[0-9]{6}$"

var clock_ms: Callable = Time.get_ticks_msec
var platform_kind: String = ""

var _client: SupabaseClient
var _track: Callable
var _sent_to: String = ""
var _sent_ms: int = -1
var _attempts: int = 0
var _busy: bool = false


func _init(client: SupabaseClient, track: Callable) -> void:
	_client = client
	_track = track


static func normalize(email: String) -> String:
	return email.strip_edges().to_lower()


static func is_valid_email(email: String) -> bool:
	var address := normalize(email)
	return address.length() <= MAX_EMAIL_LENGTH and _matches(EMAIL_PATTERN, address)


static func is_valid_code(code: String) -> bool:
	return _matches(CODE_PATTERN, code)


## Seconds before the last address may get another code (0 = now).
func cooldown_left_s() -> int:
	if _sent_ms < 0:
		return 0
	var left_ms := RESEND_COOLDOWN_S * 1000 - (int(clock_ms.call()) - _sent_ms)
	return maxi(0, ceili(left_ms / 1000.0))


func send(email: String, done: Callable) -> void:
	if _busy:
		done.call(RESULT_BUSY)
		return
	var address := normalize(email)
	if not is_valid_email(address):
		_requested(RESULT_INVALID_EMAIL, done)
		return
	var resend := address == _sent_to
	if resend and cooldown_left_s() > 0:
		_requested(RESULT_RATE_LIMITED, done)
		return
	if resend:
		_track.call("email_code_resent", {})
	else:
		_track.call("login_started", {"provider": PROVIDER, "platform": platform_kind})
	_busy = true
	_client.send_email_otp(address, func(ok: bool, status: int, body: String) -> void:
		_busy = false
		var result := RESULT_OK if ok else _send_failure(status, body)
		if ok or result == RESULT_RATE_LIMITED:
			_sent_to = address
			_sent_ms = int(clock_ms.call())
		if ok:
			_attempts = 0
		else:
			_failed("send_" + result)
		_requested(result, done))


## RESULT_OK means the client now holds the session.
func verify(email: String, code: String, done: Callable) -> void:
	if _busy:
		done.call(RESULT_BUSY)
		return
	var token := code.strip_edges()
	if not is_valid_code(token):
		done.call(RESULT_INVALID_CODE)
		return
	_busy = true
	_attempts += 1
	_client.verify_email_otp(normalize(email), token, func(ok: bool, status: int, _body: String) -> void:
		_busy = false
		if ok:
			_track.call("email_code_verified", {"attempts": _attempts})
			done.call(RESULT_OK)
			return
		var result := _verify_failure(status)
		_failed("verify_" + result)
		done.call(result))


func _requested(result: String, done: Callable) -> void:
	_track.call("email_code_requested", {"result": result})
	done.call(result)


func _failed(reason: String) -> void:
	_track.call("login_failed", {"provider": PROVIDER, "reason": reason})


static func _send_failure(status: int, body: String) -> String:
	if status == HTTP_TOO_MANY:
		return RESULT_RATE_LIMITED
	if status < HTTP_CLIENT_ERRORS.x or status > HTTP_CLIENT_ERRORS.y:
		return RESULT_ERROR
	var parsed: Variant = JsonSafe.parse(body)
	var error_code := String((parsed as Dictionary).get("error_code", "")) if parsed is Dictionary else ""
	if SETUP_ERRORS.has(error_code):
		push_warning("EmailOtp: Supabase refused to send the code (%s) - check the Email provider / SMTP" % error_code)
		return RESULT_ERROR
	return RESULT_INVALID_EMAIL


static func _verify_failure(status: int) -> String:
	if status == HTTP_TOO_MANY:
		return RESULT_RATE_LIMITED
	if status >= HTTP_CLIENT_ERRORS.x and status <= HTTP_CLIENT_ERRORS.y:
		return RESULT_WRONG_CODE
	return RESULT_ERROR


static func _matches(pattern: String, text: String) -> bool:
	var re := RegEx.create_from_string(pattern)
	return re.search(text) != null
