class_name OptionSelectScreen
extends Control
## A select step of a few side-by-side options (split out of RuleSelectScreen, design.md
## DS-LAY-03): a UiPanel of MenuButtons with one-line captions, laid out like the arena select
## (ArenaSelectLayout). ←/→ (arrows, d-pad, the stick once per push) move the focus, Z / Enter /
## Space / pad A confirm, X / Esc / pad B go back, a click or tap picks. Shown again after a later
## step backed out, the pick is open again. Subclasses override _screen_id, _title_text,
## _entries ({id, title, caption} in display order), _first_focus and _picked (id, browse_count,
## focused: the distinct ids that had the focus, in order). Tracks select_cancelled {screen, dwell_ms}.

signal cancelled

const BACK_TEXT := "뒤로"
const HINT_TEXT := "← → 고르기 · Z / Enter 확정 · X / Esc 뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)
const CONFIRM_KEYS: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const BACK_KEYS: Array[Key] = [KEY_X, KEY_ESCAPE]
## Compact options (narrower than a menu button) so three fit side by side on phones.
const OPTION_WIDTH := DS.CARD_WIDTH - DS.S5 * 2

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec

var _buttons: Array[UiMenuButton] = []
var _ids: Array[String] = []
var _focus: int = 0
var _browse: int = 0
var _focused: Array[String] = []
var _shown_ms: int = 0
var _done: bool = false
var _back: UiMenuButton
var _footer: MarginContainer
var _stick := StickNav.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown_ms = int(clock_ms.call())
	_back = ArenaSelectLayout.back_button(BACK_TEXT)
	_back.pressed.connect(back)
	var hint := ArenaSelectLayout.hint_label(HINT_TEXT)
	_footer = ArenaSelectLayout.build(self, _title_text(), _option_panel(), _back, hint)
	ArenaSelectLayout.apply_safe_area(_footer, get_viewport())
	get_viewport().size_changed.connect(func() -> void: ArenaSelectLayout.apply_safe_area(_footer, get_viewport()))
	visibility_changed.connect(_on_visibility_changed)
	_focus = clampi(_first_focus(), 0, _buttons.size() - 1)
	_note_focused(_focus)
	_buttons[_focus].grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var step := _step(event)
	if step != 0:
		move(step)
	elif _stick.owns(event):
		pass  # a held or returning stick: consumed so GUI focus navigation cannot repeat it
	elif ArenaSelectScreen._is_press(event, "ui_accept", CONFIRM_KEYS) and _back.has_focus():
		back()
	elif ArenaSelectScreen._is_press(event, "ui_accept", CONFIRM_KEYS):
		confirm()
	elif ArenaSelectScreen._is_press(event, "ui_cancel", BACK_KEYS):
		back()
	else:
		return
	get_viewport().set_input_as_handled()


## Moves the focus one option left (-1) or right (+1), wrapping around.
func move(step: int) -> void:
	_set_focus(wrapi(_focus + step, 0, _buttons.size()))
	_buttons[_focus].grab_focus()


func confirm() -> void:
	_choose(_focus)


func back() -> void:
	if _done:
		return
	_done = true
	track.call("select_cancelled", {"screen": _screen_id(), "dwell_ms": int(clock_ms.call()) - _shown_ms})
	cancelled.emit()


func buttons() -> Array[UiMenuButton]:
	return _buttons


func option_ids() -> Array[String]:
	return _ids


func focus_index() -> int:
	return _focus


func back_button() -> UiMenuButton:
	return _back


func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _screen_id() -> String:
	return ""


func _title_text() -> String:
	return ""


func _entries() -> Array[Dictionary]:
	return []


func _first_focus() -> int:
	return 0


func _picked(_id: String, _browse_count: int, _focused_ids: Array[String]) -> void:
	pass


func _choose(i: int) -> void:
	if _done or i < 0 or i >= _buttons.size():
		return
	_set_focus(i)
	_done = true
	_note_focused(i)
	_picked(_ids[i], _browse, _focused.duplicate())


func _set_focus(i: int) -> void:
	if _done:
		return
	if i != _focus:
		_browse += 1
	_focus = i
	_note_focused(i)


func _note_focused(i: int) -> void:
	if i < _ids.size() and not _focused.has(_ids[i]):
		_focused.append(_ids[i])


## Shown again after a pick (a later select step backed out to this one): a fresh visit.
func _on_visibility_changed() -> void:
	if not _done or not is_visible_in_tree():
		return
	_done = false
	_browse = 0
	_focused.clear()
	_note_focused(_focus)
	_stick = StickNav.new()
	_shown_ms = int(clock_ms.call())
	_buttons[_focus].grab_focus()


func _option_panel() -> Control:
	var entries := _entries()
	for e: Dictionary in entries:
		_ids.append(String(e["id"]))
	return OptionPanel.build(entries, OPTION_WIDTH, _buttons, _choose, _set_focus)


## -1 / +1 for a left / right press: keys and d-pad by action, the stick once per push.
func _step(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		return _stick.step(event as InputEventJoypadMotion)
	if event.is_action_pressed("ui_left"):
		return -1
	if event.is_action_pressed("ui_right"):
		return 1
	return 0
