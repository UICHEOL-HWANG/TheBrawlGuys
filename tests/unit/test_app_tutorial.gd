extends GutTest
## Onboarding in the app shell (Phase 5 T11 + DS-LAY-03 온보딩): the first sign-in on a device walks
## 환영 → 닉네임 → 캐릭터 → 시작 방식 over the title, then the tutorial (as the picked character) or
## a bot match; skipping lands on the title and is remembered, and the title's 튜토리얼 다시 보기
## replays it. Transitions off, auth faked (a stored session restores).

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
	app.profile = ProfileStore.new(SettingsStore.new(TUTORIAL_PATH))
	add_child_autofree(app)
	return app


func _props(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


## Walks the onboarding screens: start, nickname, the first character, then `choice`.
func _onboard(app: App, choice: String) -> void:
	assert_eq(app.router().current_id(), OnboardingFlow.WELCOME)
	(app.router().current() as WelcomeScreen).start()
	var nick := app.router().current() as NicknameScreen
	nick.field().text = "브롤왕"
	nick.submit()
	assert_eq(app.router().current_id(), App.CHARACTER)
	(app.router().current() as CharacterSelectScreen).confirm(0, MatchSetup.INPUT_KEYBOARD)
	assert_eq(app.router().current_id(), OnboardingFlow.CHOICE)
	(app.router().current() as OnboardingChoiceScreen).choose(choice)


func test_the_first_sign_in_onboards_then_plays_the_tutorial() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	assert_eq(app.router().current_id(), OnboardingFlow.WELCOME, "not straight into the tutorial")
	_onboard(app, OnboardingChoiceScreen.CHOICE_TUTORIAL)
	assert_eq(app.router().current_id(), App.TUTORIAL)
	assert_eq(app.router().depth(), 6, "title, the four onboarding steps, then the tutorial")
	assert_eq(app.profile.nickname(), "브롤왕")
	assert_eq(_props("nickname_set")[0], {"length": 3, "prefilled": false, "changed": false})
	assert_eq(_props("onboarding_choice")[0]["choice"], OnboardingChoiceScreen.CHOICE_TUTORIAL)
	assert_false(app.backdrop().is_inside_tree(), "the menu backdrop stops like for a match")
	assert_eq(_props("tutorial_started")[0]["source"], TutorialFlow.SOURCE_FIRST_LOGIN)
	assert_eq(_props("screen_viewed").back()["screen"], App.TUTORIAL)
	assert_eq(_props("match_started").size(), 0, "the tutorial is not a match")


func test_skipping_lands_on_the_title_and_is_not_offered_again() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	_onboard(app, OnboardingChoiceScreen.CHOICE_TUTORIAL)
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


func test_choosing_a_bot_match_starts_it_with_the_pick() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	_onboard(app, OnboardingChoiceScreen.CHOICE_BOT)
	assert_eq(app.router().current_id(), App.MATCH)
	var setup: MatchSetup = app.router().current().get("setup")
	assert_ne(setup.characters()[setup.local_slot()], CharacterData.DEFAULT, "the picked character plays")
	assert_eq(_progress().status(), TutorialProgress.SKIPPED, "not offered again on this device")
	assert_eq(_props("tutorial_started").size(), 0)


func test_back_walks_the_onboarding_steps() -> void:
	var app := _signed_in_app()
	await wait_process_frames(2)
	(app.router().current() as WelcomeScreen).start()
	(app.router().current() as NicknameScreen).back()
	assert_eq(app.router().current_id(), OnboardingFlow.WELCOME)
	(app.router().current() as WelcomeScreen).start()
	assert_eq(app.router().current_id(), OnboardingFlow.NICKNAME, "the welcome works again")


func test_the_title_greets_by_nickname() -> void:
	_progress().mark(TutorialProgress.COMPLETED)
	ProfileStore.new(SettingsStore.new(TUTORIAL_PATH)).save("브롤왕")
	var app := _signed_in_app()
	await wait_process_frames(2)
	var title := app.router().current() as TitleScreen
	assert_eq(title.greeting_text(), "브롤왕님, 반가워요")


func test_the_title_changes_the_nickname() -> void:
	_progress().mark(TutorialProgress.COMPLETED)
	ProfileStore.new(SettingsStore.new(TUTORIAL_PATH)).save("브롤왕")
	var app := _signed_in_app()
	await wait_process_frames(2)
	var title := app.router().current() as TitleScreen
	assert_eq(title.nickname_link().text, TitleScreen.CHANGE_TEXT)
	title.nickname_link().pressed.emit()
	var nick := app.router().current() as NicknameScreen
	assert_not_null(nick, "the nickname screen opens over the title")
	assert_eq(nick.field().text, "브롤왕", "starts from the current name")
	nick.field().text = "새이름"
	nick.submit()
	assert_eq(app.router().current_id(), App.TITLE, "back on the title")
	assert_eq(app.profile.nickname(), "새이름")
	assert_eq(title.greeting_text(), "새이름님, 반가워요", "the greeting follows")
	assert_eq(_props("nickname_set").back(), {"length": 3, "prefilled": true, "changed": true})


func test_a_title_without_a_nickname_offers_to_set_one() -> void:
	_progress().mark(TutorialProgress.COMPLETED)
	var app := _signed_in_app()
	await wait_process_frames(2)
	var title := app.router().current() as TitleScreen
	assert_eq(title.greeting_text(), "")
	assert_eq(title.nickname_link().text, TitleScreen.SET_TEXT)
	title.nickname_link().pressed.emit()
	(app.router().current() as NicknameScreen).back()
	assert_eq(app.router().current_id(), App.TITLE, "뒤로 leaves it unset")
	assert_eq(app.profile.nickname(), "")


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
