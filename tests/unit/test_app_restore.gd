extends GutTest
## AppRestore (platform B1): a stored-session check that fails on the spot (web OAuth return with
## ?error=) shows the login screen ready to use, never stuck in its loading state.


class FailingGate:
	extends LoginGate

	func restore() -> bool:
		failed.emit("access_denied")
		return true


func test_failure_inside_restore_shows_the_login_screen_idle() -> void:
	var router := ScreenRouter.new()
	router.animate = false
	add_child_autofree(router)
	var shown: Array = []
	var restore := AppRestore.new(router, func(reason: String, restoring: bool) -> void:
		shown.append([reason, restoring]), func(_n: String, _p: Dictionary) -> void: pass)
	var gate := FailingGate.new()
	autofree(gate)
	gate.failed.connect(func(_r: String) -> void: restore.failed(false))
	restore.begin(gate, get_tree())
	assert_eq(shown, [["refresh_failed", false]], "login screen shown ready, once")
	assert_false(restore.pending)
	await wait_seconds(AppRestore.GRACE_S + 0.2)
	assert_eq(shown.size(), 1, "no late loading screen")
