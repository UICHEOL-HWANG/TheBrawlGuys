class_name OnlineFlow
extends Node
## The online screens (Phase 6, PRD-NET-03, design.md DS-LAY-03): 온라인 on the title opens the
## OnlineMenuScreen (방 만들기 / 코드 입력, or a login prompt, or "unsupported" without WebRTC);
## a room that opens pushes the WaitingRoomScreen; the host's 경기 방식 / 경기장 reuse
## RuleSelectScreen / ArenaSelectScreen. Leaving or losing the room pops back to the online menu
## with the reason. Tracks online_lobby_viewed; OnlineRoom tracks the room events.

const MENU := "online"
const LOBBY := "lobby"
const CREATING_TEXT := "방을 만드는 중…"
const JOINING_TEXT := "방을 찾는 중…"
const OFFLINE_TEXT := "지금은 온라인에 연결할 수 없어요"

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var router: ScreenRouter
var config: GameConfig
## () -> bool
var signed_in: Callable = func() -> bool: return false
## (scene: Node) -> void — shows the match scene OnlineStart.begin returned.
var push_match: Callable = func(_scene: Node) -> void: pass
var show_login: Callable = func() -> void: pass
## () -> OnlineRoom, or null when Supabase is not available.
var room_factory: Callable = OnlineFlow.default_room
## This player's nickname (ProfileStore), told to the room so every peer can show it.
var nickname: String = ""
var supported: bool = WebRtcSupport.available()

var _menu: OnlineMenuScreen
var _room: OnlineRoom
var _lobby: WaitingRoomScreen


## Wires a flow to the app and shows the online menu.
static func open(app: App, gate: LoginGate, track_fn: Callable, push_fn: Callable, login_fn: Callable) -> OnlineFlow:
	var flow := OnlineFlow.new()
	flow.router = app.router()
	flow.config = app.backdrop().config()
	flow.track = track_fn
	flow.nickname = app.profile.nickname()
	flow.signed_in = gate.is_signed_in
	flow.push_match = push_fn
	flow.show_login = login_fn
	app.add_child(flow)
	flow.start()
	return flow


static func default_room() -> OnlineRoom:
	var client := SupabaseHub.client()
	if client == null or not client.has_session():
		return null
	var secrets := Secrets.load_from()
	var room := OnlineRoom.new()
	room.rooms = RoomsApi.new(client)
	room.socket_url = PhoenixMessage.socket_url(secrets.supabase_url, secrets.supabase_anon_key)
	room.access_token = client.session.access_token
	room.ice = WebRtcSupport.ice_config(secrets)
	return room


func start() -> void:
	var is_signed_in := bool(signed_in.call())
	_menu = OnlineMenuScreen.new()
	if not supported:
		_menu.mode = OnlineMenuScreen.Mode.UNSUPPORTED
	elif not is_signed_in:
		_menu.mode = OnlineMenuScreen.Mode.LOGIN
	_menu.create_requested.connect(_create)
	_menu.join_requested.connect(_join)
	_menu.login_requested.connect(func() -> void: show_login.call())
	_menu.cancelled.connect(func() -> void: router.pop())
	router.screen_shown.connect(_on_screen_shown)
	router.push(MENU, _menu)
	track.call("online_lobby_viewed", {"signed_in": is_signed_in, "supported": supported})


func menu() -> OnlineMenuScreen:
	return _menu


func room() -> OnlineRoom:
	return _room


func lobby() -> WaitingRoomScreen:
	return _lobby


func _create() -> void:
	if _new_room():
		_menu.set_busy(CREATING_TEXT)
		_room.create(MatchRules.STOCK, ArenaCatalog.STAGE_IDS[0])


func _join(code: String) -> void:
	if _new_room():
		_menu.set_busy(JOINING_TEXT)
		_room.join(code)


func _new_room() -> bool:
	_drop_room()
	_room = room_factory.call() as OnlineRoom
	if _room == null:
		_menu.show_error(OFFLINE_TEXT)
		return false
	_room.nickname = nickname
	add_child(_room)
	_room.opened.connect(_show_lobby)
	_room.left.connect(_on_left)
	_room.changed.connect(_refresh)
	_room.notice.connect(func(text: String) -> void:
		if _lobby != null:
			_lobby.show_notice(text))
	_room.match_ready.connect(func(scene: Node) -> void: push_match.call(scene))
	return true


func _show_lobby(code: String) -> void:
	_lobby = WaitingRoomScreen.new()
	_lobby.code = code
	_lobby.is_host = _room.is_host
	_lobby.config = config
	_lobby.leave_requested.connect(func() -> void:
		_room.leave("back")
		_on_left("back", ""))
	_lobby.pick_changed.connect(func(character: String, ready: bool) -> void: _room.peers.pick(character, ready))
	_lobby.bots_toggled.connect(func(on: bool) -> void:
		_room.peers.model.set_bots(on)
		_room.host_changed())
	_lobby.rule_requested.connect(_pick_rule)
	_lobby.arena_requested.connect(_pick_arena)
	_lobby.start_requested.connect(func() -> void: _room.start_match())
	_menu.set_idle()
	router.push(LOBBY, _lobby)
	_refresh()


func _refresh() -> void:
	if _lobby != null and _lobby.is_node_ready() and _room != null and _room.peers != null:
		_lobby.refresh(_room.peers.model, _room.peers.local_id())


func _pick_rule() -> void:
	var screen := SelectScreens.build(App.RULE, MatchSetup.new(), func() -> void: pass, config, track) as RuleSelectScreen
	screen.rule_chosen.connect(func(rule: String) -> void:
		_room.peers.model.rule = rule
		_room.host_changed()
		router.pop())
	screen.cancelled.connect(func() -> void: router.pop())
	router.push(App.RULE, screen)


func _pick_arena() -> void:
	var setup := MatchSetup.new()
	var screen := SelectScreens.build(App.ARENA, setup, func() -> void:
		_room.peers.model.arena = setup.arena_id
		_room.host_changed()
		router.pop(), config, track)
	screen.connect("cancelled", func() -> void: router.pop())
	router.push(App.ARENA, screen)


func _on_left(reason: String, message: String) -> void:
	_lobby = null
	_drop_room()
	if not is_instance_valid(_menu):
		return
	if router.current_id() != MENU:
		router.pop_to(MENU)
	if reason == "back":
		_menu.set_idle()
	else:
		_menu.show_error(message)


func _drop_room() -> void:
	if _room != null:
		_room.leave("back")
		_room.queue_free()
		_room = null


## Back on the title (온라인 menu closed, 메뉴로 after a match) or the login screen (logout):
## the room is left and the flow goes away.
func _on_screen_shown(id: String, _from: String) -> void:
	if id == App.TITLE or id == App.LOGIN:
		router.screen_shown.disconnect(_on_screen_shown)
		_drop_room()
		_menu = null
		_lobby = null
		queue_free()
