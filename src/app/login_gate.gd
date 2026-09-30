class_name LoginGate
extends Node
## The app shell's view of sign-in (platform B1/B6, PRD-AUTH-01): wraps the AuthService when keys
## are present, otherwise explains why sign-in is unavailable (Google: mobile deep links not built
## yet; both: missing secrets). Email codes work wherever the keys are. Owns the login analytics
## AuthService cannot emit: failures of an unavailable sign-in, login_skipped and logout without
## an account.

signal signed_in
signal failed(reason: String)
## A stored session was rejected or dropped (not a user action).
signal session_lost
signal signed_out

const PROVIDER := "google"
const REASON_MOBILE := "mobile_unsupported"
const REASON_NOT_CONFIGURED := "not_configured"

var platform_kind: String = PlatformEnv.kind()
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var auth: AuthService = null
var _signing_out: bool = false


## Live gate: an AuthService on the shared Supabase client when the game runs with keys.
static func create_default() -> LoginGate:
	var gate := LoginGate.new()
	var client := SupabaseHub.client()
	if client != null:
		var secrets := Secrets.load_from()
		var service := AuthService.new()
		service.setup(client, SessionStore.new(), secrets.loopback_port, secrets.redirect_web)
		gate.use_auth(service)
	return gate


func use_auth(service: AuthService) -> void:
	auth = service
	add_child(service)
	service.signed_in.connect(func(_s: SupabaseSession) -> void: signed_in.emit())
	service.sign_in_failed.connect(func(reason: String) -> void: failed.emit(reason))
	service.signed_out.connect(func() -> void:
		if not _signing_out:
			session_lost.emit())


## "" when Google sign-in can run here; otherwise the reason it cannot.
func availability() -> String:
	if platform_kind == "mobile":
		return REASON_MOBILE
	if auth == null:
		return REASON_NOT_CONFIGURED
	return ""


## Debug builds may continue offline when sign-in cannot run (design.md DS-CMP-14).
func can_skip() -> bool:
	return OS.is_debug_build() and not availability().is_empty()


func is_signed_in() -> bool:
	return auth != null and auth.is_signed_in()


## True when a stored session or web redirect is being resumed (signals follow, maybe at once).
func restore() -> bool:
	return auth != null and auth.restore()


func sign_in() -> void:
	var reason := availability()
	if reason.is_empty():
		auth.sign_in()
		return
	_track_unavailable(PROVIDER, reason)
	failed.emit(reason)


## "" when email codes can be sent here (any platform with keys); otherwise why not.
func email_availability() -> String:
	return REASON_NOT_CONFIGURED if auth == null else ""


## Seconds before the last address may get another code.
func email_cooldown_s() -> int:
	return auth.email.cooldown_left_s() if auth != null else 0


## done(result: String): EmailOtp.RESULT_* or REASON_NOT_CONFIGURED. Never emits failed.
func send_email_code(address: String, done: Callable) -> void:
	if auth == null:
		_track_unavailable(EmailOtp.PROVIDER, REASON_NOT_CONFIGURED)
		done.call(REASON_NOT_CONFIGURED)
		return
	auth.send_email_code(address, done)


## On RESULT_OK signed_in fires (before done), exactly as after Google.
func verify_email_code(address: String, code: String, done: Callable) -> void:
	if auth == null:
		done.call(REASON_NOT_CONFIGURED)
		return
	auth.verify_email_code(address, code, done)


func skip() -> void:
	track.call("login_skipped", {"reason": availability()})


func sign_out() -> void:
	_signing_out = true
	if auth != null:
		auth.sign_out()  # tracks logout
	else:
		track.call("logout", {})
	_signing_out = false
	signed_out.emit()


func _track_unavailable(provider: String, reason: String) -> void:
	track.call("login_started", {"provider": provider, "platform": platform_kind})
	track.call("login_failed", {"provider": provider, "reason": reason})
