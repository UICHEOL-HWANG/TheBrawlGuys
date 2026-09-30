extends GutTest
## Onboarding tutorial in the app shell (Phase 5 T11): the first sign-in on a device goes on into
## the tutorial over the title, skipping lands on the title and is remembered, and the title's
## 튜토리얼 다시 보기 replays it. Transitions off, auth faked (a stored session restores).

const APP_SCENE := preload("res://src/app/app.tscn")
const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const STORE_PATH := "user://test_app_tutorial_session.cfg"
const TUTORIAL_PATH := "user://test_app_tutorial.cfg"
const NOW := 1_700_000_000

var _tracked: Array = []


func before_each() -> void:
	_tracked.clear()
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	for path: String in [STORE_PATH, TUTORIAL_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _progress() -> TutorialProgress:
	return TutorialProgress.new(SettingsStore.new(TUTORIAL_PATH))


## An app whose stored session restores at once (a signed-in player opening the game).
func _signed_in_app() -> App:
	SessionStore.new(STORE_PATH).save(SupabaseSession.new("a", "r", NOW + 3600, "user-7"))
	var spy := func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog" % n)
		_tracked.append([n, p])
	var gate := LoginGate.new()
	gate.platform_kind = "desktop"
	gate.track = spy
	var client := SupabaseClient.new("https://proj.supabase.co", "anon", FakeHttp.new())
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
	app.tutorial = _progress()
	add_child_autofree(app)
	return app


func _props(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


func test_the_first_sign_in_goes_on_into_the_tutorial() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), App.TUTORIAL)
	assert_eq(app.router().depth(), 2, "the title waits underneath")
	assert_false(app.backdrop().is_inside_tree(), "the menu backdrop stops like for a match")
	assert_eq(_props("tutorial_started")[0]["source"], TutorialFlow.SOURCE_FIRST_LOGIN)
	assert_eq(_props("screen_viewed").back()["screen"], App.TUTORIAL)
	assert_eq(_props("match_started").size(), 0, "the tutorial is not a match")


func test_skipping_lands_on_the_title_and_is_not_offered_again() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	var scene := app.router().current()
	var overlay: TutorialOverlay = scene.call("overlay")
	overlay.card().skip_button().pressed.emit()
	assert_true(overlay.dialog().is_open(), "skipping asks first")
	overlay.dialog().confirm_button().pressed.emit()
	assert_eq(app.router().current_id(), App.TITLE)
	assert_true(app.backdrop().is_inside_tree())
	assert_eq(_props("tutorial_skipped")[0]["step"], TutorialSteps.MOVE)
	assert_eq(_progress().status(), TutorialProgress.SKIPPED)
	app.queue_free()
	await wait_process_frames(1)
	_tracked.clear()
	var again := _signed_in_app()
	await wait_process_frames(2)
	assert_eq(again.router().current_id(), App.TITLE, "a returning player goes straight to the title")
	assert_eq(_props("tutorial_started").size(), 0)


func test_the_title_replays_the_tutorial() -> void:
	_progress().mark(TutorialProgress.COMPLETED)
	var app := _signed_in_app()
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), App.TITLE)
	var title := app.router().current() as TitleScreen
	assert_eq(title.tutorial_button().text, TitleScreen.TUTORIAL_TEXT)
	title.tutorial_button().pressed.emit()
	title.tutorial_button().pressed.emit()
	assert_eq(app.router().current_id(), App.TUTORIAL)
	assert_eq(app.router().depth(), 2, "a double press opens one tutorial")
	assert_eq(_props("tutorial_started").size(), 1)
	assert_eq(_props("tutorial_started")[0]["source"], TutorialFlow.SOURCE_REPLAY)
	var overlay: TutorialOverlay = app.router().current().call("overlay")
	overlay.card().skip_button().pressed.emit()
	overlay.dialog().confirm_button().pressed.emit()
	assert_eq(app.router().current_id(), App.TITLE)
	assert_eq(_progress().status(), TutorialProgress.COMPLETED, "a skipped replay keeps the completion")
	await wait_process_frames(1)  # the dropped tutorial scene frees
