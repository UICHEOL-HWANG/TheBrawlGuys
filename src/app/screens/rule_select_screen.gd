class_name RuleSelectScreen
extends Control
## Rule select (combat-depth D, PRD §4.1 modes, design.md DS-LAY-03 모드 → 경기 방식 → 캐릭터 →
## 경기장 → 대전): a compact UiPanel of three MenuButtons — 스톡 / 팀전 2:2 / 시간제 — each with a
## one-line caption (RuleOptions), laid out like the arena select (ArenaSelectLayout: title, the
## panel centered, 뒤로 bottom left, key hint bottom right). ←/→ (arrows, d-pad, the stick once per
## push) move the focus, Z / Enter / Space / pad A confirm, X / Esc / pad B go back; a click or tap
## picks a button. Shown again after a later step backed out, the pick is open again. Tracks
## rule_selected {rule, browse_count} and select_cancelled {screen, dwell_ms}.

signal rule_chosen(rule: String)
signal cancelled

const SCREEN := "rule"
const TITLE_TEXT := "경기 방식"
const BACK_TEXT := "뒤로"
const HINT_TEXT := "← → 고르기 · Z / Enter 확정 · X / Esc 뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)
const CONFIRM_KEYS: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const BACK_KEYS: Array[Key] = [KEY_X, KEY_ESCAPE]
## Compact options (narrower than a menu button) so three fit side by side on phones.
const OPTION_WIDTH := DS.CARD_WIDTH - DS.S5 * 2

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec
## The app's GameConfig (stock count and timed length in the captions); null loads the default.
var config: GameConfig = null

var _buttons: Array[UiMenuButton] = []
var _rules: Array[String] = []
var _focus: int = 0
var _browse: int = 0
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
	_footer = ArenaSelectLayout.build(self, TITLE_TEXT, _option_panel(), _back, hint)
	ArenaSelectLayout.apply_safe_area(_footer, get_viewport())
	get_viewport().size_changed.connect(func() -> void: ArenaSelectLayout.apply_safe_area(_footer, get_viewport()))
	visibility_changed.connect(_on_visibility_changed)
	_buttons[0].grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var step := _step(event)
	if step != 0:
		move(step)
	elif _stick.owns(event):
		pass  # a held or returning stick: consumed so GUI focus navigation cannot repeat it
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
	track.call("select_cancelled", {"screen": SCREEN, "dwell_ms": int(clock_ms.call()) - _shown_ms})
	cancelled.emit()


func buttons() -> Array[UiMenuButton]:
	return _buttons


func rule_ids() -> Array[String]:
	return _rules


func focus_index() -> int:
	return _focus


func back_button() -> UiMenuButton:
	return _back


func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _choose(i: int) -> void:
	if _done or i < 0 or i >= _buttons.size():
		return
	_set_focus(i)
	_done = true
	track.call("rule_selected", {"rule": _rules[i], "browse_count": _browse})
	rule_chosen.emit(_rules[i])


func _set_focus(i: int) -> void:
	if _done:
		return
	if i != _focus:
		_browse += 1
	_focus = i


## Shown again after a pick (a later select step backed out to this one): a fresh visit.
func _on_visibility_changed() -> void:
	if not _done or not is_visible_in_tree():
		return
	_done = false
	_browse = 0
	_stick = StickNav.new()
	_shown_ms = int(clock_ms.call())
	_buttons[_focus].grab_focus()


func _option_panel() -> Control:
	var panel := UiPanel.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S5)
	panel.add_child(row)
	var cfg := config if config != null else load(MenuBackdrop.CONFIG_PATH) as GameConfig
	for e: Dictionary in RuleOptions.entries(cfg):
		row.add_child(_option(e))
	return panel


func _option(e: Dictionary) -> Control:
	var i := _buttons.size()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	var b := UiMenuButton.new()
	b.text = String(e["title"])
	b.ready.connect(func() -> void: b.custom_minimum_size.x = OPTION_WIDTH)
	b.pressed.connect(_choose.bind(i))
	b.focus_entered.connect(_set_focus.bind(i))
	col.add_child(b)
	var caption := ArenaSelectLayout.hint_label(String(e["caption"]))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = OPTION_WIDTH
	caption.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	col.add_child(caption)
	_buttons.append(b)
	_rules.append(String(e["rule"]))
	return col


## -1 / +1 for a left / right press: keys and d-pad by action, the stick once per push.
func _step(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		return _stick.step(event as InputEventJoypadMotion)
	if event.is_action_pressed("ui_left"):
		return -1
	if event.is_action_pressed("ui_right"):
		return 1
	return 0
