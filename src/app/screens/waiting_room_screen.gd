class_name WaitingRoomScreen
extends Control
## Online waiting room (Phase 6, PRD-NET-03, design.md DS-LAY-03 대기실): the room code big with
## 복사 (web: navigator.clipboard through JavaScriptBridge), four slots (PlayerSlot + connection
## badge with ping) and a control column — 캐릭터 (cycles), 준비 / 준비 취소, and for the host
## 경기 방식 · 경기장 (open the existing select screens) · 봇 채우기 / 봇 빼기 · 시작 (only when
## LobbyModel.can_start; otherwise the reason shows under it) — then 나가기. Keys / pad move the
## focus between buttons, Esc / pad B leaves; taps and clicks work everywhere.

signal leave_requested
signal start_requested
signal rule_requested
signal arena_requested
signal bots_toggled(on: bool)
signal pick_changed(character: String, ready: bool)

const CODE_CAPTION := "방 코드"
const COPY_TEXT := "복사"
const COPIED_TEXT := "코드를 복사했어요"
const READY_TEXT := "준비"
const UNREADY_TEXT := "준비 취소"
const CHARACTER_FORMAT := "캐릭터 · %s"
const RULE_FORMAT := "경기 방식 · %s"
const ARENA_FORMAT := "경기장 · %s"
const BOTS_ON_TEXT := "봇 채우기"
const BOTS_OFF_TEXT := "봇 빼기"
const START_TEXT := "시작"
const LEAVE_TEXT := "나가기"
const ME_SUFFIX := " · 나"
const HOST_SUFFIX := " · 방장"
const BACKDROP_FOCUS := Vector2(0.0, 0.5)

var code: String = ""
var is_host: bool = false
## The app's GameConfig (rule titles); null loads the default.
var config: GameConfig = null
## (text: String) -> void; tests capture it.
var copy_text: Callable = WaitingRoomScreen.clipboard_copy

var _code_label: Label
var _cells: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _block: Label
var _notice: Label
var _character: String = CharacterData.IDS[0]
var _is_ready: bool = false
var _bots: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if config == null:
		config = load(MenuBackdrop.CONFIG_PATH) as GameConfig
	var head := WaitingRoomLayout.header(CODE_CAPTION, COPY_TEXT)
	_code_label = head["code"]
	_code_label.text = code
	(head["copy"] as UiMenuButton).pressed.connect(copy_code)
	var parts := WaitingRoomLayout.body(self, head["root"])
	_cells = WaitingRoomLayout.slot_grid(parts["slots"], LobbyModel.MAX_SLOTS)
	_build_controls(parts["controls"])
	(_buttons["ready"] as Control).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		leave_requested.emit()
		get_viewport().set_input_as_handled()


## Redraws everything from the room state; local_id = this device's peer id (0 = not yet assigned).
func refresh(model: LobbyModel, local_id: int) -> void:
	for i: int in _cells.size():
		_show_slot(_cells[i], model.slots[i], local_id)
	var mine := model.slot_of(local_id)
	if mine >= 0:
		_character = String(model.slots[mine]["character"])
		_is_ready = bool(model.slots[mine]["ready"])
	_bots = model.has_bots()
	button("character").text = CHARACTER_FORMAT % CharacterCards.title_of(_character)
	button("ready").text = UNREADY_TEXT if _is_ready else READY_TEXT
	button("rule").text = RULE_FORMAT % _rule_title(model.rule)
	button("arena").text = ARENA_FORMAT % String((ArenaCards.NAMES.get(model.arena, [model.arena]) as Array)[0])
	button("bots").text = BOTS_OFF_TEXT if _bots else BOTS_ON_TEXT
	WaitingRoomLayout.set_enabled(button("start"), model.can_start())
	_block.text = model.start_block()


func show_notice(text: String) -> void:
	_notice.text = text


func notice_text() -> String:
	return _notice.text


func button(id: String) -> UiMenuButton:
	return _buttons.get(id) as UiMenuButton


func slot(i: int) -> PlayerSlot:
	return _cells[i]["slot"]


func connection(i: int) -> ConnectionBadge:
	return _cells[i]["conn"]


func code_text() -> String:
	return _code_label.text


func copy_code() -> void:
	copy_text.call(code)
	show_notice(COPIED_TEXT)


func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


static func clipboard_copy(text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(text), true)
	else:
		DisplayServer.clipboard_set(text)


func _build_controls(box: Container) -> void:
	var own := {
		"character": func() -> void: _cycle_character(),
		"ready": func() -> void: pick_changed.emit(_character, not _is_ready),
	}
	var host := {
		"rule": func() -> void: rule_requested.emit(), "arena": func() -> void: arena_requested.emit(),
		"bots": func() -> void: bots_toggled.emit(not _bots), "start": func() -> void: start_requested.emit(),
	}
	for id: String in own:
		_add_button(box, id, UiMenuButton.Kind.SECONDARY, own[id])
	for id: String in host:
		var b := _add_button(box, id, UiMenuButton.Kind.PRIMARY if id == "start" else UiMenuButton.Kind.SECONDARY,
				host[id])
		b.visible = is_host
	(_buttons["start"] as UiMenuButton).text = START_TEXT
	_block = WaitingRoomLayout.caption("")
	_block.visible = is_host
	box.add_child(_block)
	_add_button(box, "leave", UiMenuButton.Kind.SECONDARY, func() -> void: leave_requested.emit()).text = LEAVE_TEXT
	_notice = WaitingRoomLayout.caption("")
	box.add_child(_notice)


func _add_button(box: Container, id: String, kind: UiMenuButton.Kind, on_press: Callable) -> UiMenuButton:
	var b := WaitingRoomLayout.button("", kind)
	b.pressed.connect(on_press)
	box.add_child(b)
	_buttons[id] = b
	return b


func _cycle_character() -> void:
	var order := CharacterCards.ORDER
	var next := order[(order.find(_character) + 1) % order.size()]
	pick_changed.emit(next, _is_ready)


func _show_slot(cell: Dictionary, s: Dictionary, local_id: int) -> void:
	var view: PlayerSlot = cell["slot"]
	var peer := int(s["peer"])
	view.set_bot(peer == LobbyModel.BOT)
	var title := "" if peer == LobbyModel.EMPTY else CharacterCards.title_of(String(s["character"]))
	if peer == local_id and peer > 0:
		title += ME_SUFFIX
	elif peer == LobbyModel.HOST_ID:
		title += HOST_SUFFIX
	view.set_character(title)
	if peer == LobbyModel.EMPTY:
		view.set_state(PlayerSlot.State.EMPTY)
	elif s["conn"] == LobbyModel.CONN_FAILED:
		view.set_state(PlayerSlot.State.DISCONNECTED)
	else:
		view.set_state(PlayerSlot.State.READY if bool(s["ready"]) else PlayerSlot.State.CHOOSING)
	(cell["conn"] as ConnectionBadge).set_conn(String(s["conn"]) if peer > LobbyModel.HOST_ID else "", int(s["rtt"]))


func _rule_title(rule: String) -> String:
	for e: Dictionary in RuleOptions.entries(config):
		if e["rule"] == rule:
			return String(e["title"])
	return rule

