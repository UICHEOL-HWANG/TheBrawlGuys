extends GutTest
## App shell flow (platform B1, PRD §6.5): login → title → match → 메뉴로 → title → logout, session
## restore straight to the title, and the analytics the shell emits. Transitions off, auth faked.

const APP_SCENE := preload("res://src/app/app.tscn")
const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_app_session.cfg"
const NOW := 1_700_000_000

var _tracked: Array = []
var _http: FakeHttp


func after_each() -> void:
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


func _app(with_auth: bool) -> App:
	_tracked.clear()
	var spy := func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog" % n)
		_tracked.append([n, p])
	var gate := LoginGate.new()
	gate.platform_kind = "desktop"
	gate.track = spy
	if with_auth:
		_http = FakeHttp.new()
		var client := SupabaseClient.new("https://proj.supabase.co", "anon", _http)
		client.now_s = func() -> int: return NOW
		client.net_error_sink = func(_e: String, _s: int) -> void: pass
		var auth := AuthService.new()
		auth.platform_kind = "desktop"
		auth.track = spy
		auth.identify = func(_u: String) -> void: pass
		auth.setup(client, SessionStore.new(STORE_PATH), 54321, "")
		gate.use_auth(auth)
	var app := APP_SCENE.instantiate() as App
	app.animate = false
	app.gate = gate
	app.track = spy
	add_child_autofree(app)
	return app


func _names() -> Array[String]:
	var out: Array[String] = []
	for t: Array in _tracked:
		out.append(String(t[0]))
	return out


func _props(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


func test_the_app_is_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://src/app/app.tscn")


func test_offline_login_skip_match_menu_and_logout() -> void:
	var app := _app(false)
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), App.LOGIN)
	assert_eq(_props("login_viewed")[0]["reason"], "no_session")
	var login := app.router().current() as LoginScreen
	assert_true(login.panel().google_button().disabled, "no keys: Google is off")
	assert_eq(login.panel().message_text(), LoginMessages.NOT_CONFIGURED)
	assert_true(login.panel().skip_button().visible, "debug build can skip")
	login.panel().skip_button().pressed.emit()
	assert_eq(app.router().current_id(), App.TITLE)
	assert_true(_names().has("login_skipped"))
	var title := app.router().current() as TitleScreen
	await wait_process_frames(1)
	assert_true(title.mode_button(MatchSetup.MODE_LOCAL_2P).disabled, "로컬 2인 · 준비 중")
	assert_true(title.mode_button(MatchSetup.MODE_ONLINE).disabled)
	title.mode_button(MatchSetup.MODE_BOT).pressed.emit()
	assert_eq(_props("mode_selected")[0]["mode"], MatchSetup.MODE_BOT)
	assert_eq(app.router().current_id(), App.MATCH)
	assert_false(app.backdrop().is_inside_tree(), "the backdrop stops during a match")
	var match_scene := app.router().current()
	assert_eq((match_scene.get("setup") as MatchSetup).mode, MatchSetup.MODE_BOT)
	await wait_seconds(0.2)
	var w: World = match_scene.call("get_world")
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_seconds(0.2)
	var hud: Hud = match_scene.call("get_hud")
	assert_true(hud.menu_button().visible)
	hud.menu_button().pressed.emit()
	assert_eq(app.router().current_id(), App.TITLE)
	assert_true(app.backdrop().is_inside_tree(), "the backdrop is back")
	var back := _props("screen_viewed").back() as Dictionary
	assert_eq(back["screen"], App.TITLE)
	assert_eq(back["from_screen"], App.MATCH)
	title.logout_button().pressed.emit()
	assert_eq(app.router().current_id(), App.LOGIN)
	assert_true(_names().has("logout"))
	assert_eq(_props("login_viewed").back()["reason"], "logged_out")


func test_restored_session_skips_the_login_screen() -> void:
	SessionStore.new(STORE_PATH).save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	var app := _app(true)
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), App.TITLE)
	assert_true(_names().has("session_restored"))
	assert_false(_names().has("login_viewed"), "the login screen was never shown")


func test_rejected_refresh_shows_the_login_screen() -> void:
	SessionStore.new(STORE_PATH).save(SupabaseSession.new("a", "r", NOW, "user-7"))
	var app := _app(true)
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), App.LOGIN)
	var login := app.router().current() as LoginScreen
	assert_eq(login.panel().state(), LoginPanel.State.LOADING, "checking the stored session")
	assert_false(_names().has("login_viewed"))
	_http.respond(400, "{}")
	assert_eq(login.panel().state(), LoginPanel.State.IDLE)
	assert_false(login.panel().google_button().disabled)
	assert_eq(_props("login_viewed")[0]["reason"], "refresh_failed")


func test_desktop_sign_in_goes_to_the_title() -> void:
	var app := _app(true)
	await wait_process_frames(2)
	var login := app.router().current() as LoginScreen
	assert_false(login.panel().skip_button().visible, "sign-in works here: no skip")
	var loop := LoopbackStub.new()
	app.gate.auth.loopback = loop
	app.gate.auth.open_url = func(_u: String) -> Error: return OK
	login.panel().google_button().pressed.emit()
	assert_eq(login.panel().state(), LoginPanel.State.LOADING)
	loop.result = {"code": "c-1"}
	app.gate.auth.poll()
	_http.respond(200, JSON.stringify({"access_token": "a", "refresh_token": "r", "expires_in": 3600,
		"user": {"id": "user-9"}}))
	assert_eq(app.router().current_id(), App.TITLE)
	assert_true(_names().has("login_completed"))


class LoopbackStub extends LoopbackServer:
	var result: Dictionary = {}

	func start(_port: int, _now_ms: int) -> Error:
		return OK

	func poll(_now_ms: int) -> Dictionary:
		return result

	func stop() -> void:
		pass
