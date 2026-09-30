class_name ArenaSelectScreen
extends Control
## Arena select (Phase 4 T7, PRD-UI-02, design.md DS-LAY-03 … → 경기장 선택 → 대전): a title, one
## SelectCard per stage (ArenaCards) in a centered row and a 뒤로 button over the menu backdrop
## (ArenaSelectLayout). ←/→ (arrows, d-pad, the stick once per push) move the focus, Z / Enter /
## Space confirm, X / Esc go back; hovering a card focuses it and a click or tap picks it. Shown
## again after a pick (a later step backed out), the pick is cleared. Tracks arena_selected
## {arena, browse_count} and select_cancelled {screen, dwell_ms}; screen_viewed comes from the
## ScreenRouter.

signal arena_chosen(arena_id: String)
signal cancelled

const SCREEN := "arena"
const TITLE_TEXT := "경기장 선택"
const BACK_TEXT := "뒤로"
const HINT_TEXT := "← → 고르기 · Z / Enter 확정 · X / Esc 뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)
const CARD_SCENE := preload("res://src/ui/components/select_card/select_card.tscn")
const CONFIRM_KEYS: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const BACK_KEYS: Array[Key] = [KEY_X, KEY_ESCAPE]

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec
## The app's GameConfig (the arena previews are built from it); null loads the default config.
var config: GameConfig = null

var _cards: Array[SelectCard] = []
var _ids: Array[String] = []
var _focus: int = 0
var _browse: int = 0
var _shown_ms: int = 0
var _done: bool = false
var _back: UiMenuButton
var _hint: Label
var _footer: MarginContainer
var _stick := StickNav.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown_ms = int(clock_ms.call())
	_back = ArenaSelectLayout.back_button(BACK_TEXT)
	_back.pressed.connect(back)
	_hint = ArenaSelectLayout.hint_label(HINT_TEXT)
	_footer = ArenaSelectLayout.build(self, TITLE_TEXT, _card_row(), _back, _hint)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	visibility_changed.connect(_on_visibility_changed)
	if not _cards.is_empty():
		_cards[0].grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var step := _step(event)
	if step != 0:
		move(step)
	elif _is_press(event, "ui_accept", CONFIRM_KEYS):
		confirm()
	elif _is_press(event, "ui_cancel", BACK_KEYS):
		back()
	else:
		return
	get_viewport().set_input_as_handled()


## Moves the focus one card left (-1) or right (+1), wrapping around.
func move(step: int) -> void:
	if _cards.is_empty():
		return
	var target := wrapi(_focus + step, 0, _cards.size())
	_cards[target].grab_focus()  # focus_entered also lands in _set_focus
	_set_focus(target)


func confirm() -> void:
	_choose(_focus)


func back() -> void:
	if _done:
		return
	_done = true
	track.call("select_cancelled", {"screen": SCREEN, "dwell_ms": int(clock_ms.call()) - _shown_ms})
	cancelled.emit()


func cards() -> Array[SelectCard]:
	return _cards


func card_ids() -> Array[String]:
	return _ids


func focus_index() -> int:
	return _focus


func back_button() -> UiMenuButton:
	return _back


func hint_label() -> Label:
	return _hint


## Title on top, cards in the middle: the backdrop fight plays above them.
func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _choose(i: int) -> void:
	if _done or i < 0 or i >= _cards.size() or _cards[i].state() == SelectCard.State.LOCKED:
		return
	_set_focus(i)
	_done = true
	_set_cards_live(false)
	_cards[i].set_state(SelectCard.State.SELECTED)
	track.call("arena_selected", {"arena": _ids[i], "browse_count": _browse})
	arena_chosen.emit(_ids[i])


func _set_focus(i: int) -> void:
	if _done:
		return  # hovering after a pick changes nothing
	if i != _focus:
		_browse += 1
	_focus = i


## Shown again after a pick (a later select step backed out to this one): a fresh visit.
func _on_visibility_changed() -> void:
	if not _done or not is_visible_in_tree():
		return
	_done = false
	_browse = 0
	_shown_ms = int(clock_ms.call())
	_set_cards_live(true)
	for i: int in _cards.size():
		if _cards[i].state() != SelectCard.State.LOCKED:
			_cards[i].set_state(SelectCard.State.FOCUS if i == _focus else SelectCard.State.IDLE)
	_cards[_focus].grab_focus()


func _set_cards_live(on: bool) -> void:
	for c: SelectCard in _cards:
		c.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _card_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfg := config if config != null else load(MenuBackdrop.CONFIG_PATH) as GameConfig
	var entries := ArenaCards.entries(cfg)
	for i: int in entries.size():
		var e := entries[i]
		var card := CARD_SCENE.instantiate() as SelectCard
		row.add_child(card)
		card.setup(String(e["title"]), String(e["caption"]), e["diorama"], e["icons"])
		card.pressed.connect(_choose.bind(i))
		card.focus_entered.connect(_set_focus.bind(i))
		_cards.append(card)
		_ids.append(String(e["id"]))
	return row


func _apply_safe_area() -> void:
	ArenaSelectLayout.apply_safe_area(_footer, get_viewport())


## -1 / +1 for a left / right press: keys and d-pad by action, the stick once per push.
func _step(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		return _stick.step(event as InputEventJoypadMotion)
	if event.is_action_pressed("ui_left"):
		return -1
	if event.is_action_pressed("ui_right"):
		return 1
	return 0


static func _is_press(event: InputEvent, action: String, keys: Array[Key]) -> bool:
	var key := event as InputEventKey
	if key != null and key.echo:
		return false
	if event.is_action_pressed(action):
		return true
	return key != null and key.pressed and keys.has(key.keycode)
