class_name LoginScreen
extends Control
## Login screen (platform B1/B6, PRD §5.7): the LoginPanel over the backdrop, driven by a LoginGate.
## Google → loading until the browser returns; a failure shows one line and the retry button;
## when Google cannot run here its button stays off, with the reason, and debug builds may skip.
## Email codes (LoginEmailFlow) run wherever the keys are, mobile included. Success is handled by
## the app shell (it listens to the gate).

signal skipped

const PANEL_SCENE := preload("res://src/ui/components/login_panel/login_panel.tscn")

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var _gate: LoginGate
var _restoring: bool = false
var _panel: LoginPanel
var _email: LoginEmailFlow


## Call before adding to the tree. restoring = a stored session is being checked.
func setup(gate: LoginGate, restoring: bool) -> void:
	_gate = gate
	_restoring = restoring


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PANEL_SCENE.instantiate() as LoginPanel
	add_child(_panel)
	_panel.google_pressed.connect(_on_google)
	_panel.skip_pressed.connect(_on_skip)
	_email = LoginEmailFlow.new(_panel, _gate)
	_panel.language_changed.connect(func(old: String, new: String) -> void:
		track.call("settings_changed", {"key": "language", "old": old, "new": new}))
	_gate.failed.connect(_on_failed)
	show_idle("")
	if _restoring:
		_panel.set_state(LoginPanel.State.LOADING, LoginMessages.RESTORING)
	await get_tree().process_frame  # containers size the layout before the entrance
	if is_inside_tree():
		_panel.play_entrance()


## Back to idle (a restore ended without a session), with an optional one-line note.
func show_idle(note: String) -> void:
	var why := LoginMessages.unavailable(_gate.availability())
	var email_ok := _gate.email_availability().is_empty()
	_panel.set_google_enabled(why.is_empty())
	_panel.set_email_enabled(email_ok)
	_panel.set_skip_visible(_gate.can_skip())
	_panel.set_state(LoginPanel.State.IDLE, why if not why.is_empty() else note)
	if why.is_empty():
		_panel.google_button().grab_focus.call_deferred()
	elif email_ok:
		_panel.email_button().grab_focus.call_deferred()


func _process(_delta: float) -> void:
	if _email != null:
		_email.tick()


func panel() -> LoginPanel:
	return _panel


func backdrop_focus() -> Vector2:
	return _panel.backdrop_focus()


func _on_google() -> void:
	_panel.set_state(LoginPanel.State.LOADING, LoginMessages.WAITING)
	_gate.sign_in()


func _on_failed(reason: String) -> void:
	_panel.set_state(LoginPanel.State.ERROR, LoginMessages.for_failure(reason))


func _on_skip() -> void:
	_gate.skip()
	skipped.emit()
