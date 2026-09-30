class_name TutorialCard
extends UiPanel
## The tutorial's mission card (Phase 5 T11, design.md DS-CMP-19): a Panel (DS-CMP-07) at the top
## center with a caption row "튜토리얼 · 3/8" and a secondary 건너뛰기 MenuButton, the mission
## title (display, `title`) and one instruction line (body). States: mission · success (title
## "좋아요!", a squish bump, `motion_squish`) · complete (title "튜토리얼 완료!" and a primary
## "타이틀로" button instead of 건너뛰기). 건너뛰기 never takes focus (Space is also jump), and
## the card never blocks touches outside its buttons.

signal skip_pressed
signal exit_pressed

enum Mode { MISSION, SUCCESS, COMPLETE }

const WIDTH := 760
const TAG_FORMAT := "튜토리얼 · %d/%d"
const SUCCESS_TITLE := "좋아요!"
const SUCCESS_LINE := "다음 미션으로 넘어가요"
const COMPLETE_TITLE := "튜토리얼 완료!"
const COMPLETE_LINE := "이제 봇 대전에서 실력을 뽐내 보세요"
const SKIP_TEXT := "건너뛰기"
const EXIT_TEXT := "타이틀로"
const SUCCESS_BUMP := 1.06
const GOAL_BUMP := 1.03

var _mode: int = Mode.MISSION
var _tag: Label
var _title: Label
var _line: Label
var _skip: UiMenuButton
var _exit: UiMenuButton


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_tag = text_label(DS.FONT_CAPTION_PATH, DS.SIZE_CAPTION, DS.UI_TEXT_SOFT)
	_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tag)
	_skip = _button(SKIP_TEXT, UiMenuButton.Kind.SECONDARY, skip_pressed)
	head.add_child(_skip)
	_title = text_label(DS.FONT_DISPLAY_PATH, DS.SIZE_TITLE, DS.UI_TEXT)
	col.add_child(_title)
	_line = text_label(DS.FONT_BODY_PATH, DS.SIZE_BODY, DS.UI_TEXT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	_exit = _button(EXIT_TEXT, UiMenuButton.Kind.PRIMARY, exit_pressed)
	_exit.size_flags_horizontal = Control.SIZE_SHRINK_END
	_exit.visible = false
	col.add_child(_exit)


func _ready() -> void:
	super._ready()
	custom_minimum_size.x = WIDTH
	_skip.custom_minimum_size = Vector2(0, DS.S7)
	_skip.focus_mode = Control.FOCUS_NONE
	_exit.custom_minimum_size = Vector2(DS.BUTTON_MIN_WIDTH * 0.5, DS.S7)


## A mission (goal_index > 0 = the second goal of the same mission: a small bump, same title).
func show_mission(index: int, count: int, title: String, line: String, goal_index: int = 0) -> void:
	_mode = Mode.MISSION
	_tag.text = TAG_FORMAT % [index, count]
	_title.text = title
	_line.text = line
	if goal_index > 0 and is_inside_tree():
		UiMotion.bump(self, GOAL_BUMP)


## The same mission told for another device (the player picked up a pad, touched the screen).
func set_line(line: String) -> void:
	if _mode == Mode.MISSION:
		_line.text = line


func show_success() -> void:
	_mode = Mode.SUCCESS
	_title.text = SUCCESS_TITLE
	_line.text = SUCCESS_LINE
	if is_inside_tree():
		UiMotion.bump(self, SUCCESS_BUMP)


func show_complete() -> void:
	_mode = Mode.COMPLETE
	_title.text = COMPLETE_TITLE
	_line.text = COMPLETE_LINE
	_skip.visible = false
	_exit.visible = true
	if is_inside_tree():
		UiMotion.bump(self, SUCCESS_BUMP)
		_focus_exit.call_deferred()


func _focus_exit() -> void:
	if _exit.is_inside_tree() and _exit.visible:
		_exit.grab_focus()


func mode() -> int:
	return _mode


func title_text() -> String:
	return _title.text


func line_text() -> String:
	return _line.text


func tag_text() -> String:
	return _tag.text


func skip_button() -> UiMenuButton:
	return _skip


func exit_button() -> UiMenuButton:
	return _exit


func set_preview() -> void:
	show_mission(3, TutorialSteps.count(), TutorialSteps.title(TutorialSteps.LIGHT),
			TutorialText.line(TutorialSteps.G_LIGHT_HIT, TutorialText.DEVICE_KEYBOARD))


func _button(text: String, kind: UiMenuButton.Kind, sig: Signal) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = kind
	b.pressed.connect(func() -> void: sig.emit())
	return b


static func text_label(font_path: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
