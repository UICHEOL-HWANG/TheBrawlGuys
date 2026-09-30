class_name CodeInput
extends Control
## 6-digit code input (design.md DS-CMP-18): six cream rounded boxes, one digit each. A hidden
## LineEdit over the boxes takes the keys, paste and the mobile numeric keyboard; anything that
## is not a digit is dropped and at most six are kept. States idle · focus (the next box gets
## the petal-yellow ring) · error (every box rings danger until the player types) · disabled.

signal code_changed(code: String)
## Six digits are in.
signal completed(code: String)
## Enter pressed.
signal submitted(code: String)

enum State { IDLE, FOCUS, ERROR, DISABLED }

const LENGTH := 6
const GAP := DS.S3

var _state: int = State.IDLE
var _field: LineEdit
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(LENGTH * DS.CODE_BOX_WIDTH + (LENGTH - 1) * GAP, DS.CODE_BOX_HEIGHT)
	_font = load(DS.FONT_BODY_PATH) as Font
	_field = LineEdit.new()
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_field.flat = true
	for style: String in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for color: String in ["font_color", "font_uneditable_color", "caret_color", "selection_color"]:
		_field.add_theme_color_override(color, DS.TRANSPARENT)
	_field.text_changed.connect(_on_text_changed)
	_field.text_submitted.connect(func(_t: String) -> void: submitted.emit(code()))
	_field.focus_entered.connect(func() -> void: _follow(State.FOCUS))
	_field.focus_exited.connect(func() -> void: _follow(State.IDLE))
	add_child(_field)


## Digits of `text`, at most `limit` of them.
static func digits(text: String, limit: int = LENGTH) -> String:
	var out := ""
	for ch: String in text:
		if out.length() >= limit:
			break
		if ch >= "0" and ch <= "9":
			out += ch
	return out


func code() -> String:
	return _field.text


func set_code(text: String) -> void:
	_field.text = text
	_on_text_changed(text)


func clear() -> void:
	set_code("")


func grab_input_focus() -> void:
	_field.grab_focus()


## The LineEdit taking the input (tests, focus neighbours).
func field() -> LineEdit:
	return _field


func set_state(s: int) -> void:
	_state = s
	_field.editable = s != State.DISABLED
	queue_redraw()


func state() -> int:
	return _state


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before adding its column to the tree
	set_code("4829")


func _on_text_changed(text: String) -> void:
	var clean := digits(text)
	if clean != text:
		_field.text = clean
		_field.caret_column = clean.length()
	if _state == State.ERROR:
		set_state(State.FOCUS if _field.has_focus() else State.IDLE)
	queue_redraw()
	code_changed.emit(clean)
	if clean.length() == LENGTH:
		completed.emit(clean)


## Focus changes never override error or disabled.
func _follow(s: int) -> void:
	if _state == State.ERROR or _state == State.DISABLED:
		return
	set_state(s)


func _draw() -> void:
	var text := code()
	var box_size := Vector2(DS.CODE_BOX_WIDTH, DS.CODE_BOX_HEIGHT)
	var baseline := (box_size.y + _font.get_ascent(DS.SIZE_TITLE) - _font.get_descent(DS.SIZE_TITLE)) * 0.5
	for i: int in LENGTH:
		var at := Vector2(i * (box_size.x + GAP), 0)
		draw_style_box(_box(i == text.length()), Rect2(at, box_size))
		if i < text.length():
			draw_string(_font, at + Vector2(0, baseline), text[i], HORIZONTAL_ALIGNMENT_CENTER, box_size.x,
					DS.SIZE_TITLE, DS.UI_TEXT)


func _box(next: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(DS.RADIUS_S)
	if _state == State.DISABLED:
		sb.bg_color = DS.UI_SURFACE_DIM
		return sb
	sb.bg_color = DS.UI_SURFACE
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = DS.SHADOW_PRESSED_OFFSET
	sb.shadow_size = DS.SHADOW_PRESSED_SIZE
	if _state == State.ERROR or (_state == State.FOCUS and next):
		sb.border_color = DS.DANGER if _state == State.ERROR else DS.PETAL_YELLOW
		sb.set_border_width_all(DS.STROKE_FOCUS)
	return sb
