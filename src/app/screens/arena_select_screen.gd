class_name ArenaSelectScreen
extends Control
## Arena select (Phase 4 T7, PRD-UI-02, design.md DS-LAY-03 … → 경기장 선택 → 대전): a title, one
## SelectCard per stage (ArenaCards) in a row and a 뒤로 button over the menu backdrop.
## ←/→ (arrows, gamepad) move the focus, Z / Enter / Space confirm, X / Esc go back; hovering a
## card focuses it and a click or tap picks it. Tracks arena_selected {arena, browse_count} and
## select_cancelled {screen, dwell_ms}; screen_viewed comes from the ScreenRouter.

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

var _cards: Array[SelectCard] = []
var _ids: Array[String] = []
var _focus: int = 0
var _browse: int = 0
var _shown_ms: int = 0
var _done: bool = false
var _back: UiMenuButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown_ms = int(clock_ms.call())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_gap(DS.S6), LoginLayout.title_label(TITLE_TEXT), fill, _card_row(), _gap(DS.S5), _footer(), _gap(DS.S6)]:
		col.add_child(c)
	if not _cards.is_empty():
		_cards[0].grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var echo := key != null and key.echo
	if event.is_action_pressed("ui_left"):
		move(-1)
	elif event.is_action_pressed("ui_right"):
		move(1)
	elif not echo and (event.is_action_pressed("ui_accept") or _is_key(event, CONFIRM_KEYS)):
		confirm()
	elif not echo and (event.is_action_pressed("ui_cancel") or _is_key(event, BACK_KEYS)):
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


## Title on top, cards low: the backdrop fight plays in between.
func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _choose(i: int) -> void:
	if _done or i < 0 or i >= _cards.size() or _cards[i].state() == SelectCard.State.LOCKED:
		return
	_done = true
	_set_focus(i)
	_cards[i].set_state(SelectCard.State.SELECTED)
	track.call("arena_selected", {"arena": _ids[i], "browse_count": _browse})
	arena_chosen.emit(_ids[i])


func _set_focus(i: int) -> void:
	if i != _focus:
		_browse += 1
	_focus = i


func _card_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entries := ArenaCards.entries(GameConfig.new())
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


func _footer() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = UiMenuButton.new()
	_back.text = BACK_TEXT
	_back.kind = UiMenuButton.Kind.SECONDARY
	_back.focus_mode = Control.FOCUS_NONE  # keys move between cards only; X / Esc goes back
	_back.pressed.connect(back)
	row.add_child(_back)
	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	hint.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	hint.add_theme_color_override("font_color", DS.UI_TEXT)  # dark on the light menu haze
	row.add_child(hint)
	return row


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


static func _is_key(event: InputEvent, keys: Array[Key]) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and keys.has(key.keycode)
