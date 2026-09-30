class_name PlayerSlot
extends PanelContainer
## A participant (design.md DS-CMP-10, DS-VIS-03): one header row — the player's marker (color +
## shape), number ("P1"), a 봇 tag for bots, the character it plays and the status — over the
## button prompts of the device that player uses (PromptRow, DS-TOK-06). States: empty (dim, "비어 있음") · choosing
## · ready (a stroke_focus ring in the player color) · disconnected (dim, marker dimmed —
## the Phase 6 online placeholder).

enum State { EMPTY, CHOOSING, READY, DISCONNECTED }

const STATUS := {
	State.EMPTY: "비어 있음", State.CHOOSING: "고르는 중", State.READY: "준비 완료",
	State.DISCONNECTED: "연결 끊김",
}
const BOT_TEXT := "봇"
const MIN_WIDTH := 400
const MARKER_SIZE := DS.S6

var _index: int = 0
var _state: int = State.EMPTY
var _marker: PlayerMarker
var _number: Label
var _status: Label
var _bot: Label
var _character: Label
var _prompts: PromptRow


func _init() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", DS.S3)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_marker = PlayerMarker.new()
	head.add_child(_marker)
	_number = _label(DS.FONT_DISPLAY_PATH, DS.SIZE_TITLE, DS.UI_TEXT)
	head.add_child(_number)
	_bot = _label(DS.FONT_CAPTION_PATH, DS.SIZE_CAPTION, DS.UI_TEXT_SOFT)
	_bot.text = BOT_TEXT
	_bot.visible = false
	head.add_child(_bot)
	_character = _label(DS.FONT_BODY_PATH, DS.SIZE_BODY, DS.UI_TEXT)
	_character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_character)
	_status = _label(DS.FONT_CAPTION_PATH, DS.SIZE_CAPTION, DS.UI_TEXT_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_status)
	_prompts = PromptRow.new()
	col.add_child(_prompts)


func _ready() -> void:
	custom_minimum_size.x = MIN_WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


## Player index (0 = P1): number, color and shape.
func setup(index: int) -> void:
	_index = index
	_marker.setup(index, MARKER_SIZE)
	_number.text = PlayerStyle.label(index)
	_apply()


func set_state(s: int) -> void:
	_state = s
	_apply()


func state() -> int:
	return _state


func set_character(title: String) -> void:
	_character.text = title


func set_bot(on: bool) -> void:
	_bot.visible = on


func set_prompts(rows: Array[Dictionary]) -> void:
	_prompts.set_rows(rows)


func number_text() -> String:
	return _number.text


func status_text() -> String:
	return _status.text


func character_text() -> String:
	return _character.text


func marker() -> PlayerMarker:
	return _marker


func bot_tag() -> Label:
	return _bot


func prompt_row() -> PromptRow:
	return _prompts


func set_preview() -> void:
	setup(1)
	set_character("나이트")
	set_prompts(SelectPrompts.for_player("p2", SelectPrompts.DEVICE_KEYBOARD))
	set_state(State.READY)


func _apply() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(DS.RADIUS_L)
	box.set_content_margin_all(DS.S4)
	var dim := _state == State.EMPTY or _state == State.DISCONNECTED
	box.bg_color = DS.UI_SURFACE_DIM if dim else DS.UI_SURFACE
	box.shadow_color = DS.UI_SHADOW
	box.shadow_offset = DS.SHADOW_SOFT_OFFSET
	box.shadow_size = DS.SHADOW_SOFT_SIZE
	if _state == State.READY:
		box.border_color = PlayerStyle.color(_index)
		box.set_border_width_all(DS.STROKE_FOCUS)
	add_theme_stylebox_override("panel", box)
	_status.text = String(STATUS[_state])
	_status.add_theme_color_override("font_color", DS.UI_TEXT if _state == State.READY else DS.UI_TEXT_SOFT)
	_marker.set_dimmed(_state == State.DISCONNECTED)
	_character.add_theme_color_override("font_color", DS.UI_TEXT_SOFT if dim else DS.UI_TEXT)


static func _label(font_path: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
