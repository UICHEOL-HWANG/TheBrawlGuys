class_name App
extends Node
## App shell and main scene (platform B1, PRD §6.5, design.md DS-LAY-03): the menu backdrop keeps
## brawling behind a screen stack — login (skipped when a stored session is restored) → title →
## match — and the app owns the login gate. Entering a match swaps the backdrop out under the
## curtain; 메뉴로 on the result banner brings it back. Character and arena select come later:
## they will fill the MatchSetup that mode select starts today.

const BACKDROP_SCENE := preload("res://src/app/menu_backdrop/menu_backdrop.tscn")
const MATCH_SCENE := preload("res://src/main/main.tscn")
const UI_LAYER := 10
const LOGIN := "login"
const TITLE := "title"
const MATCH := "match"

## Tests turn transitions off; set before adding the app to the tree.
var animate: bool = true
var gate: LoginGate = null
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)

var _backdrop: MenuBackdrop
var _router: ScreenRouter
var _restoring: bool = false


func _ready() -> void:
	_backdrop = BACKDROP_SCENE.instantiate() as MenuBackdrop
	add_child(_backdrop)
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	add_child(ui)
	_router = ScreenRouter.new()
	_router.animate = animate
	_router.track = track
	_router.world_parent = self
	ui.add_child(_router)
	_router.screen_shown.connect(_on_screen_shown)
	if gate == null:
		gate = LoginGate.create_default()
	add_child(gate)
	gate.signed_in.connect(_on_signed_in)
	gate.session_lost.connect(_on_restore_failed.bind(true))
	gate.failed.connect(func(_reason: String) -> void: _on_restore_failed(false))
	_restoring = gate.restore()
	if _router.depth() == 0:
		_show_login("no_session", _restoring)
	if animate:
		_backdrop.reveal()


func _exit_tree() -> void:
	if _backdrop != null and not _backdrop.is_inside_tree():
		_backdrop.free()  # detached during a match: not freed with the tree


func router() -> ScreenRouter:
	return _router


func backdrop() -> MenuBackdrop:
	return _backdrop


func _show_login(reason: String, restoring: bool = false) -> void:
	var screen := LoginScreen.new()
	screen.track = track
	screen.setup(gate, restoring)
	screen.skipped.connect(_show_title)
	if _router.depth() == 0:
		_router.push(LOGIN, screen)
	else:
		_router.reset(LOGIN, screen, true, _attach_backdrop)
	if not restoring:
		track.call("login_viewed", {"reason": reason})


func _show_title() -> void:
	var screen := TitleScreen.new()
	screen.mode_chosen.connect(_on_mode_chosen)
	screen.logout_requested.connect(_on_logout)
	if _router.depth() == 0:
		_router.push(TITLE, screen)
	else:
		_router.replace(TITLE, screen)


## Menu screens say where they leave room; the backdrop slides its fight there.
func _on_screen_shown(_id: String, _from: String) -> void:
	var screen := _router.current()
	if screen != null and screen.has_method("backdrop_focus"):
		_backdrop.set_focus(screen.call("backdrop_focus") as Vector2)


func _on_signed_in() -> void:
	_restoring = false
	if _router.depth() == 0 or _router.current_id() == LOGIN:
		_show_title()


## A stored session could not be resumed: the login screen becomes usable (and is counted).
func _on_restore_failed(session_dropped: bool) -> void:
	if not _restoring:
		return
	_restoring = false
	if session_dropped and _router.current() is LoginScreen:
		(_router.current() as LoginScreen).show_idle(LoginMessages.for_failure("refresh_"))
	track.call("login_viewed", {"reason": "refresh_failed"})


func _on_mode_chosen(mode: String) -> void:
	track.call("mode_selected", {"mode": mode})
	if mode != MatchSetup.MODE_BOT:
		return  # 로컬 2인 · 온라인: shown disabled until Phase 5/6
	var setup := MatchSetup.vs_bots()
	setup.mode = mode
	var match_scene := MATCH_SCENE.instantiate()
	match_scene.set("setup", setup)
	match_scene.set("menu_available", true)
	match_scene.connect("menu_requested", _back_to_title)
	_router.push(MATCH, match_scene, true, _detach_backdrop)


func _back_to_title() -> void:
	_router.pop(true, _attach_backdrop)


func _on_logout() -> void:
	gate.sign_out()
	_show_login("logged_out")


func _detach_backdrop() -> void:
	if _backdrop.is_inside_tree():
		remove_child(_backdrop)


func _attach_backdrop() -> void:
	if not _backdrop.is_inside_tree():
		add_child(_backdrop)
		move_child(_backdrop, 0)
