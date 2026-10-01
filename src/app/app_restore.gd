class_name AppRestore
extends RefCounted
## The stored-session check at launch (platform B1): while it runs only the menu backdrop shows, so
## a session that restores or refreshes goes straight to the title with no login screen flashing in
## between (and no backdrop slide from the login spot to the title spot). A check slower than
## GRACE_S shows the login screen in its loading state; a failed one shows it ready to sign in.

const GRACE_S := 1.5

## true while the stored session is being checked.
var pending: bool = false
var _router: ScreenRouter
## (reason: String, restoring: bool) -> void — App._show_login.
var _show_login: Callable
var _track: Callable


func _init(router: ScreenRouter, show_login: Callable, track: Callable) -> void:
	_router = router
	_show_login = show_login
	_track = track


## Starts the check; a session restored on the spot has already shown the title (signed_in).
## pending is set first: restore() may sign in or fail on the spot (web OAuth return with ?error=).
func begin(gate: LoginGate, tree: SceneTree) -> void:
	pending = true
	var checking := gate.restore()
	if not pending or _router.depth() > 0:
		pending = false  # settled on the spot: the title or the login screen is already up
		return
	if not checking:
		pending = false
		_show_login.call("no_session", false)
		return
	tree.create_timer(GRACE_S).timeout.connect(_on_slow, CONNECT_ONE_SHOT)


func signed_in() -> void:
	pending = false


## The stored session could not be resumed: the login screen becomes usable (and is counted).
func failed(session_dropped: bool) -> void:
	if not pending:
		return
	pending = false
	if _router.depth() == 0:
		_show_login.call("refresh_failed", false)
	else:
		_track.call("login_viewed", {"reason": "refresh_failed"})
	if session_dropped and _router.current() is LoginScreen:
		(_router.current() as LoginScreen).show_idle(LoginMessages.for_failure("refresh_"))


func _on_slow() -> void:
	if pending and is_instance_valid(_router) and _router.depth() == 0:
		_show_login.call("no_session", true)
