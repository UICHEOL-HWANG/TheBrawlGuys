extends GutTest
## App shell flow (platform B1, PRD §6.5): login → title → match → 메뉴로 → title → logout, session
## restore straight to the title, and the analytics the shell emits. Transitions off, auth faked.

const APP_SCENE := preload("res://src/app/app.tscn")
const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_app_session.cfg"
## A device that already saw the tutorial (the first-login tutorial: test_app_tutorial).
const TUTORIAL_PATH := "user://test_app_tutorial_done.cfg"
const NOW := 1_700_000_000

var _tracked: Array = []
var _http: FakeHttp


func after_each() -> void:
	for path: String in [STORE_PATH, TUTORIAL_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


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
	app.tutorial = TutorialProgress.new(SettingsStore.new(TUTORIAL_PATH))
	app.tutorial.mark(TutorialProgress.COMPLETED)
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
	assert_false(title.mode_button(MatchSetup.MODE_LOCAL_2P).disabled, "로컬 2인 is live on desktop")
	assert_true(title.mode_button(MatchSetup.MODE_ONLINE).disabled)
	title.mode_button(MatchSetup.MODE_BOT).pressed.emit()
	assert_eq(_props("mode_selected")[0]["mode"], MatchSetup.MODE_BOT)
	assert_eq(app.router().current_id(), App.CHARACTER, "bot match: pick a character first")
	var chars := app.router().current() as CharacterSelectScreen
	await wait_process_frames(1)
	chars.view().cards[2].press()
	var picked := _props("character_selected")
	assert_eq(picked.size(), 2, "one per slot: the human and the bot")
	assert_eq([picked[0]["character"], picked[0]["is_bot"]], [CharacterData.KNIGHT, false])
	assert_true(bool(picked[1]["is_bot"]))
	assert_eq(app.router().current_id(), App.ARENA, "then the arena")
	var arenas := app.router().current() as ArenaSelectScreen
	assert_same(arenas.config, app.backdrop().config(), "the previews use the app's config")
	await wait_process_frames(1)
	arenas.cards()[2].press()
	assert_eq(_props("arena_selected")[0]["arena"], arenas.card_ids()[2])
	assert_eq(app.router().current_id(), App.MATCH)
	assert_false(app.backdrop().is_inside_tree(), "the backdrop stops during a match")
	var match_scene := app.router().current()
	assert_eq((match_scene.get("setup") as MatchSetup).mode, MatchSetup.MODE_BOT)
	assert_eq((match_scene.get("setup") as MatchSetup).arena_id, arenas.card_ids()[2], "the match is on the chosen arena")
	var world_now: World = match_scene.call("get_world")
	assert_eq(world_now.fighters[0].character, CharacterData.KNIGHT, "the sim plays the chosen character")
	assert_eq(world_now.fighters[1].character, String(picked[1]["character"]), "and the bot's drawn one")
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


func test_backing_out_walks_the_select_steps_back_to_the_title() -> void:
	var app := _app(false)
	await wait_process_frames(2)
	(app.router().current() as LoginScreen).panel().skip_button().pressed.emit()
	(app.router().current() as TitleScreen).mode_button(MatchSetup.MODE_BOT).pressed.emit()
	assert_eq(app.router().current_id(), App.CHARACTER)
	var viewed := _props("screen_viewed").back() as Dictionary
	assert_eq([viewed["screen"], viewed["from_screen"]], [App.CHARACTER, App.TITLE])
	var chars := app.router().current() as CharacterSelectScreen
	await wait_process_frames(1)
	chars.confirm(0, "keyboard")
	assert_eq(app.router().current_id(), App.ARENA)
	(app.router().current() as ArenaSelectScreen).back()
	assert_eq(app.router().current_id(), App.CHARACTER, "back from the arena: the character select again")
	assert_eq(chars.model().state(0), CharacterSelectModel.CHOOSING, "and the pick is open again")
	chars.cancel(0)
	assert_eq(app.router().current_id(), App.TITLE, "cancel while choosing leaves")
	var screens: Array = _props("select_cancelled").map(func(p: Dictionary) -> String: return p["screen"])
	assert_eq(screens, [App.ARENA, App.CHARACTER])
	assert_true(app.backdrop().is_inside_tree(), "the backdrop never left")


func test_local_2p_picks_characters_and_an_arena_then_starts_two_humans() -> void:
	var app := _app(false)
	await wait_process_frames(2)
	(app.router().current() as LoginScreen).panel().skip_button().pressed.emit()
	var title := app.router().current() as TitleScreen
	await wait_process_frames(1)
	title.mode_button(MatchSetup.MODE_LOCAL_2P).pressed.emit()
	assert_eq(_props("mode_selected")[0]["mode"], MatchSetup.MODE_LOCAL_2P)
	assert_eq(app.router().current_id(), App.CHARACTER, "local 2P: both pick a character")
	var chars := app.router().current() as CharacterSelectScreen
	await wait_process_frames(1)
	chars.confirm(1, "keyboard")
	assert_eq(app.router().current_id(), App.CHARACTER, "P2 alone is not enough")
	chars.confirm(0, "keyboard")
	assert_eq(app.router().current_id(), App.ARENA, "local 2P also picks an arena")
	await wait_process_frames(1)
	(app.router().current() as ArenaSelectScreen).cards()[0].press()
	assert_eq(app.router().current_id(), App.MATCH)
	var setup := app.router().current().get("setup") as MatchSetup
	assert_eq(setup.mode, MatchSetup.MODE_LOCAL_2P)
	assert_eq(setup.local_slots(), [0, 1] as Array[int])
	assert_eq(setup.characters(), [CharacterData.BARBARIAN, CharacterData.ROGUE] as Array[String],
			"P1 kept the first card, P2 the second")
	var picked := _props("character_selected")
	assert_eq(picked.map(func(p: Dictionary) -> bool: return p["is_bot"]), [false, false])


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
