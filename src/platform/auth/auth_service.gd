class_name AuthService
extends Node
## Sign-in through Supabase Auth (platform A4/B6, PRD-AUTH-01). Google with PKCE — web: redirect
## to the provider, then restore() reads ?code= on the reload; desktop: loopback server on
## 127.0.0.1 + system browser; mobile: not supported yet (deep links, context P2). Email with a
## 6-digit code (EmailOtp) works on every platform. Sessions persist in SessionStore and are
## refreshed on start. Emits login_* analytics.

signal signed_in(session: SupabaseSession)
signal sign_in_failed(reason: String)
signal signed_out

const PROVIDER := "google"

var platform_kind: String = PlatformEnv.kind()
var loopback: LoopbackServer = LoopbackServer.new()
var web: WebCallback = WebCallback.new()
var open_url: Callable = OS.shell_open
var clock_ms: Callable = Time.get_ticks_msec
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var identify: Callable = func(user_id: String) -> void: Analytics.identify(user_id)
## Email code sign-in on the same client; created by setup().
var email: EmailOtp = null

var _client: SupabaseClient
var _store: SessionStore
var _port: int
var _redirect_web: String
var _verifier: String = ""
var _listening: bool = false


func setup(client: SupabaseClient, store: SessionStore, loopback_port: int, redirect_web: String) -> void:
	_client = client
	_store = store
	_port = loopback_port
	_redirect_web = redirect_web
	_client.session_changed.connect(_on_session_changed)
	email = EmailOtp.new(client, func(event_name: String, props: Dictionary) -> void: track.call(event_name, props))


func is_signed_in() -> bool:
	return _client != null and _client.has_session()


## Resumes a web redirect or a stored session; false when there is nothing to resume.
func restore() -> bool:
	if platform_kind == "web":
		var query := web.read_query()
		# Only our own redirect: a sign-in left a verifier before leaving the page.
		var pending := not web.peek_verifier().is_empty()
		if pending and (query.has("code") or query.has("error")):
			web.clean_url()
			if query.has("error"):
				web.take_verifier()
				_fail(String(query["error"]))
			else:
				_exchange(String(query["code"]), web.take_verifier())
			return true
	var stored := _store.load_session()
	if stored == null:
		return false
	_client.session = stored
	if not stored.is_expiring(int(_client.now_s.call()), SupabaseClient.REFRESH_MARGIN_S):
		_restored()
		return true
	_client.refresh(func(ok: bool, status: int, _message: String) -> void:
		if ok:
			_restored()
		elif _client.has_session():
			# Not rejected (offline, server error): stay signed out for now, keep the file for next start.
			_client.session = null
			_fail("refresh_%d" % status))
	return true


func sign_in() -> void:
	track.call("login_started", {"provider": PROVIDER, "platform": platform_kind})
	if platform_kind == "mobile":
		_fail("mobile_unsupported")
		return
	if _client == null:
		_fail("not_configured")
		return
	var verifier := Pkce.new_verifier()
	if platform_kind == "web":
		# Come back to the page the player is on: the verifier lives in that origin's storage.
		var here := web.current_url()
		var target := here if not here.is_empty() else _redirect_web
		web.save_verifier(verifier)
		web.redirect(AuthUrls.authorize(_client.url(), PROVIDER, target, Pkce.challenge(verifier)))
		return
	var nonce := AuthUrls.new_state()
	loopback.expect_state(nonce)
	if loopback.start(_port, int(clock_ms.call())) != OK:
		_fail("loopback_port_busy")
		return
	_verifier = verifier
	_listening = true
	var redirect := AuthUrls.loopback_redirect(_port, nonce)
	var url := AuthUrls.authorize(_client.url(), PROVIDER, redirect, Pkce.challenge(verifier))
	if open_url.call(url) != OK:
		_stop_listening()
		_fail("browser_open_failed")


## Mails a 6-digit code. done(result: String), one of EmailOtp.RESULT_*.
func send_email_code(address: String, done: Callable) -> void:
	email.platform_kind = platform_kind
	email.send(address, done)


## Signs in with the mailed code; on RESULT_OK signed_in fires first, as for Google.
func verify_email_code(address: String, code: String, done: Callable) -> void:
	email.platform_kind = platform_kind
	email.verify(address, code, func(result: String) -> void:
		if result == EmailOtp.RESULT_OK:
			_completed(EmailOtp.PROVIDER)
		done.call(result))


func sign_out() -> void:
	_stop_listening()
	if _client != null:
		_client.sign_out()
	track.call("logout", {})


func poll() -> void:
	if not _listening:
		return
	var result := loopback.poll(int(clock_ms.call()))
	if result.is_empty():
		return
	_listening = false
	if result.has("code"):
		_exchange(String(result["code"]), _verifier)
	else:
		_fail(String(result.get("error", "unknown")))
	_verifier = ""


func _process(_delta: float) -> void:
	poll()


func _exit_tree() -> void:
	_stop_listening()


func _exchange(code: String, verifier: String) -> void:
	if verifier.is_empty():
		_fail("missing_verifier")
		return
	_client.exchange_pkce(code, verifier, func(ok: bool, status: int, _message: String) -> void:
		if not ok:
			_fail("exchange_%d" % status)
			return
		_completed(PROVIDER))


func _completed(provider: String) -> void:
	track.call("login_completed", {"provider": provider, "platform": platform_kind})
	identify.call(_client.session.user_id)
	signed_in.emit(_client.session)


func _restored() -> void:
	track.call("session_restored", {})
	identify.call(_client.session.user_id)
	signed_in.emit(_client.session)


func _fail(reason: String) -> void:
	push_warning("AuthService: sign-in failed (%s)" % reason)
	track.call("login_failed", {"provider": PROVIDER, "reason": reason})
	sign_in_failed.emit(reason)


func _on_session_changed(session: SupabaseSession) -> void:
	if session != null:
		_store.save(session)
		return
	_store.clear()
	identify.call("")
	signed_out.emit()


func _stop_listening() -> void:
	if _listening:
		loopback.stop()
	_listening = false
