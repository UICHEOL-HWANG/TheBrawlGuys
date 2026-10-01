class_name OnlineMenuScreen
extends Control
## Online entry (Phase 6, PRD-NET-03, design.md DS-LAY-03): laid out like the arena select
## (ArenaSelectLayout) with one Panel. Signed in on a platform with WebRTC: 방 만들기 (primary), a
## RoomCodeInput (DS-CMP-11) and 입장 (secondary, live once six characters are in; Enter works
## too) and a status line. Not signed in: a login prompt. No WebRTC (desktop without the
## webrtc-native plugin): WebRtcSupport.UNSUPPORTED_TEXT. Esc / pad B / 뒤로 go back.

signal create_requested
signal join_requested(code: String)
signal login_requested
signal cancelled

enum Mode { READY, LOGIN, UNSUPPORTED }

const TITLE_TEXT := "온라인"
const CREATE_TEXT := "방 만들기"
const JOIN_TEXT := "입장"
const CODE_LABEL := "친구에게 받은 방 코드"
const LOGIN_PROMPT := "온라인 대전은 로그인한 뒤에 할 수 있어요"
const LOGIN_TEXT := "로그인"
const BACK_TEXT := "뒤로"
const HINT_TEXT := "Enter 입장 · Esc 뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)

var mode: Mode = Mode.READY

var _create: UiMenuButton
var _join: UiMenuButton
var _login: UiMenuButton
var _code: RoomCodeInput
var _status: Label
var _back: UiMenuButton
var _busy: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = ArenaSelectLayout.back_button(BACK_TEXT)
	_back.pressed.connect(back)
	var footer := ArenaSelectLayout.build(self, TITLE_TEXT, _panel(), _back,
			ArenaSelectLayout.hint_label(HINT_TEXT if mode == Mode.READY else ""))
	ArenaSelectLayout.apply_safe_area(footer, get_viewport())
	_focus_first.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).pressed
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		back()
		get_viewport().set_input_as_handled()


func back() -> void:
	if not _busy:
		cancelled.emit()


func submit_code() -> void:
	if _busy or _code == null or not RoomCode.is_valid(_code.code()):
		return
	join_requested.emit(_code.code())


## Waiting on the network: buttons off, the status line says what is happening.
func set_busy(text: String) -> void:
	_busy = true
	_set_status(text, DS.UI_TEXT_SOFT)
	_refresh()


## Usable again (back from a room): buttons on, the status line shows text (soft).
func set_idle(text: String = "") -> void:
	_busy = false
	_set_status(text, DS.UI_TEXT_SOFT)
	_refresh()


func show_error(text: String) -> void:
	_busy = false
	_set_status(text, DS.DANGER)
	if _code != null:
		_code.set_state(CodeInput.State.ERROR)
	_refresh()


func status_text() -> String:
	return _status.text


func create_button() -> UiMenuButton:
	return _create


func join_button() -> UiMenuButton:
	return _join


func login_button() -> UiMenuButton:
	return _login


func code_input() -> RoomCodeInput:
	return _code


func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _panel() -> Control:
	var panel := UiPanel.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S4)
	panel.add_child(col)
	_status = ArenaSelectLayout.hint_label("")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = DS.BUTTON_MIN_WIDTH
	match mode:
		Mode.UNSUPPORTED:
			_set_status(WebRtcSupport.UNSUPPORTED_TEXT, DS.UI_TEXT)
		Mode.LOGIN:
			_set_status(LOGIN_PROMPT, DS.UI_TEXT)
			_login = _button(LOGIN_TEXT, UiMenuButton.Kind.PRIMARY, func() -> void: login_requested.emit())
			col.add_child(_login)
		Mode.READY:
			_build_ready(col)
	col.add_child(_status)
	return panel


func _build_ready(col: VBoxContainer) -> void:
	_create = _button(CREATE_TEXT, UiMenuButton.Kind.PRIMARY, func() -> void:
		if not _busy:
			create_requested.emit())
	col.add_child(_create)
	var label := ArenaSelectLayout.hint_label(CODE_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	_code = RoomCodeInput.new()
	_code.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_code.code_changed.connect(func(_c: String) -> void: _refresh())
	_code.submitted.connect(func(_c: String) -> void: submit_code())
	col.add_child(_code)
	_join = _button(JOIN_TEXT, UiMenuButton.Kind.SECONDARY, submit_code)
	col.add_child(_join)
	_refresh.call_deferred()


func _button(text: String, kind: UiMenuButton.Kind, on_press: Callable) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = kind
	b.pressed.connect(on_press)
	return b


func _refresh() -> void:
	WaitingRoomLayout.set_enabled(_create, not _busy)
	if _code != null:
		WaitingRoomLayout.set_enabled(_join, not _busy and RoomCode.is_valid(_code.code()))


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _focus_first() -> void:
	for b: UiMenuButton in [_create, _login]:
		if b != null:
			b.grab_focus()
			return
	_back.focus_mode = Control.FOCUS_ALL
	_back.grab_focus()
