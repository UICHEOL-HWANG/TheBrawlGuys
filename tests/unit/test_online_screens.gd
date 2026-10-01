extends GutTest
## Online UI (Phase 6, design.md DS-CMP-11 / DS-CMP-13, DS-LAY-03): the room code input, the
## connection badge, the online menu's three modes, the waiting room's slots and controls, and
## 온라인 on the title.

const APP_SCENE := preload("res://src/app/app.tscn")
const TUTORIAL_PATH := "user://test_online_tutorial_done.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TUTORIAL_PATH):
		DirAccess.remove_absolute(TUTORIAL_PATH)


func _add(node: Control) -> Control:
	add_child_autofree(node)
	return node


func test_room_code_input_keeps_room_code_letters_only() -> void:
	var input := _add(RoomCodeInput.new()) as RoomCodeInput
	var done: Array = []
	input.completed.connect(func(c: String) -> void: done.append(c))
	input.set_code("k7-qw io 2z")
	assert_eq(input.code(), "K7QW2Z")
	assert_eq(done, ["K7QW2Z"])
	assert_eq(input.field().virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_DEFAULT)
	var digits := _add(CodeInput.new()) as CodeInput
	digits.set_code("12ab34")
	assert_eq(digits.code(), "1234", "the email code input still keeps digits only")


func test_connection_badge_states_and_ping_colors() -> void:
	var badge := _add(ConnectionBadge.new()) as ConnectionBadge
	assert_false(badge.visible, "none: hidden")
	badge.set_conn("connecting")
	assert_eq([badge.visible, badge.text(), badge.color()], [true, "연결 중", DS.PETAL_YELLOW])
	badge.set_conn("connected", 42)
	assert_eq([badge.text(), badge.color()], ["연결됨 · 42ms", DS.GRASS_MID])
	badge.set_conn("connected", 180)
	assert_eq(badge.color(), DS.PETAL_YELLOW)
	badge.set_conn("connected", 400)
	assert_eq(badge.color(), DS.DANGER)
	badge.set_conn("failed")
	assert_eq([badge.text(), badge.color()], ["연결 실패", DS.DANGER])


func test_online_menu_ready_mode_joins_with_a_full_code() -> void:
	var menu := OnlineMenuScreen.new()
	_add(menu)
	await wait_process_frames(2)
	var joins: Array = []
	menu.join_requested.connect(func(c: String) -> void: joins.append(c))
	assert_true(menu.join_button().disabled, "no code yet")
	menu.code_input().set_code("k7qw2")
	menu.submit_code()
	assert_eq(joins, [], "five characters are not a code")
	menu.code_input().set_code("k7qw2z")
	assert_false(menu.join_button().disabled)
	menu.join_button().pressed.emit()
	assert_eq(joins, ["K7QW2Z"])
	menu.set_busy("방을 찾는 중…")
	assert_true(menu.create_button().disabled)
	menu.show_error("그 코드의 방이 없어요")
	assert_eq(menu.status_text(), "그 코드의 방이 없어요")
	assert_false(menu.create_button().disabled)


func test_online_menu_login_and_unsupported_modes() -> void:
	var login := OnlineMenuScreen.new()
	login.mode = OnlineMenuScreen.Mode.LOGIN
	_add(login)
	var asked: Array = []
	login.login_requested.connect(func() -> void: asked.append(true))
	assert_null(login.create_button())
	login.login_button().pressed.emit()
	assert_eq(asked, [true])
	var none := OnlineMenuScreen.new()
	none.mode = OnlineMenuScreen.Mode.UNSUPPORTED
	_add(none)
	assert_eq(none.status_text(), WebRtcSupport.UNSUPPORTED_TEXT)
	assert_null(none.create_button())


func _lobby(is_host: bool) -> WaitingRoomScreen:
	var screen := WaitingRoomScreen.new()
	screen.code = "K7QW2Z"
	screen.is_host = is_host
	_add(screen)
	return screen


func test_waiting_room_shows_slots_connection_and_the_start_rule() -> void:
	var screen := _lobby(true)
	await wait_process_frames(1)
	var m := LobbyModel.new()
	m.add_human(1)
	m.add_human(2)
	screen.refresh(m, 1)
	assert_eq(screen.code_text(), "K7QW2Z")
	assert_string_contains(screen.slot(0).character_text(), "나")
	assert_eq(screen.slot(1).state(), PlayerSlot.State.CHOOSING)
	assert_string_contains(screen.slot(1).character_text(), CharacterCards.title_of(CharacterData.IDS[0]))
	assert_eq(screen.slot(2).state(), PlayerSlot.State.EMPTY)
	assert_eq(screen.connection(1).state(), ConnectionBadge.State.CONNECTING)
	assert_false(screen.connection(0).visible, "no badge on the host's own slot")
	assert_true(screen.button("start").disabled)
	m.set_pick(1, CharacterData.KNIGHT, true)
	m.set_pick(2, CharacterData.MAGE, true)
	m.set_conn(2, LobbyModel.CONN_CONNECTED, 55)
	screen.refresh(m, 1)
	assert_eq(screen.slot(1).state(), PlayerSlot.State.READY)
	assert_eq(screen.connection(1).text(), "연결됨 · 55ms")
	assert_false(screen.button("start").disabled, "two ready, connected humans")
	m.set_conn(2, LobbyModel.CONN_FAILED)
	screen.refresh(m, 1)
	assert_eq(screen.slot(1).state(), PlayerSlot.State.DISCONNECTED)
	assert_true(screen.button("start").disabled)


func test_waiting_room_controls_emit_and_client_has_no_host_controls() -> void:
	var screen := _lobby(false)
	await wait_process_frames(1)
	var m := LobbyModel.new()
	m.add_human(1)
	m.add_human(2)
	screen.refresh(m, 2)
	assert_string_contains(screen.slot(0).character_text(), "방장")
	for id: String in ["rule", "arena", "bots", "start"]:
		assert_false(screen.button(id).visible, id + " is the host's")
	var picks: Array = []
	screen.pick_changed.connect(func(c: String, r: bool) -> void: picks.append([c, r]))
	screen.button("ready").pressed.emit()
	screen.button("character").pressed.emit()
	assert_eq(picks, [[CharacterData.IDS[0], true], [CharacterCards.ORDER[1], false]])
	var copied: Array = []
	screen.copy_text = func(t: String) -> void: copied.append(t)
	screen.copy_code()
	assert_eq(copied, ["K7QW2Z"])
	assert_eq(screen.notice_text(), WaitingRoomScreen.COPIED_TEXT)


func test_title_online_opens_the_online_menu() -> void:
	var tracked: Array = []
	var gate := LoginGate.new()
	gate.platform_kind = "desktop"
	gate.track = func(_n: String, _p: Dictionary) -> void: pass
	var app := APP_SCENE.instantiate() as App
	app.animate = false
	app.gate = gate
	app.track = func(event_name: String, props: Dictionary) -> void:
		assert_eq(EventCatalog.validate(event_name, props).size(), 0, event_name)
		tracked.append([event_name, props])
	app.tutorial = TutorialProgress.new(SettingsStore.new(TUTORIAL_PATH))
	app.tutorial.mark(TutorialProgress.COMPLETED)
	add_child_autofree(app)
	await wait_process_frames(2)
	(app.router().current() as LoginScreen).panel().skip_button().pressed.emit()
	await wait_process_frames(1)
	(app.router().current() as TitleScreen).mode_button(MatchSetup.MODE_ONLINE).pressed.emit()
	assert_eq(app.router().current_id(), OnlineFlow.MENU)
	var menu := app.router().current() as OnlineMenuScreen
	var expected := OnlineMenuScreen.Mode.LOGIN if WebRtcSupport.available() else OnlineMenuScreen.Mode.UNSUPPORTED
	assert_eq(menu.mode, expected, "not signed in (or no WebRTC here)")
	var viewed: Array = tracked.filter(func(t: Array) -> bool: return t[0] == "online_lobby_viewed")
	assert_eq(viewed.size(), 1)
	assert_eq(viewed[0][1], {"signed_in": false, "supported": WebRtcSupport.available()})
	menu.back()
	assert_eq(app.router().current_id(), App.TITLE)
