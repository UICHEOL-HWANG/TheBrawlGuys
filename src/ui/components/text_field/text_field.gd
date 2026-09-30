class_name UiTextField
extends LineEdit
## Text field (design.md DS-CMP-17): a cream rounded box with body text for short input (the
## login email). States idle · focus (petal-yellow ring, also on hover) · error (danger ring
## until the player types again) · disabled (dim surface, read only). Callers set the mobile
## keyboard hint (virtual_keyboard_type) and the placeholder.

enum State { IDLE, FOCUS, ERROR, DISABLED }

var _state: int = State.IDLE


func _ready() -> void:
	custom_minimum_size.y = DS.FIELD_HEIGHT
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", load(DS.FONT_BODY_PATH) as Font)
	add_theme_font_size_override("font_size", DS.SIZE_BODY)
	add_theme_color_override("font_color", DS.UI_TEXT)
	add_theme_color_override("font_uneditable_color", DS.UI_TEXT_SOFT)
	add_theme_color_override("font_placeholder_color", DS.UI_TEXT_SOFT)
	add_theme_color_override("caret_color", DS.UI_TEXT)
	add_theme_color_override("selection_color", DS.GLOW)
	focus_entered.connect(func() -> void: _follow(State.FOCUS))
	focus_exited.connect(func() -> void: _follow(State.IDLE))
	mouse_entered.connect(func() -> void: _follow(State.FOCUS))
	mouse_exited.connect(func() -> void: _follow(State.FOCUS if has_focus() else State.IDLE))
	text_changed.connect(func(_t: String) -> void:
		if _state == State.ERROR:
			set_state(State.FOCUS if has_focus() else State.IDLE))
	_apply()


func set_state(s: int) -> void:
	_state = s
	editable = s != State.DISABLED
	_apply()


func state() -> int:
	return _state


func set_preview() -> void:
	placeholder_text = "you@example.com"
	custom_minimum_size.x = DS.BUTTON_MIN_WIDTH


## Focus/hover changes never override error or disabled.
func _follow(s: int) -> void:
	if _state == State.ERROR or _state == State.DISABLED:
		return
	set_state(s)


func _apply() -> void:
	var box := _box(_state)
	for style: String in ["normal", "focus"]:
		add_theme_stylebox_override(style, box)
	add_theme_stylebox_override("read_only", _box(State.DISABLED))


func _box(s: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(DS.RADIUS_M)
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = DS.S3
	sb.content_margin_bottom = DS.S3
	sb.bg_color = DS.UI_SURFACE_DIM if s == State.DISABLED else DS.UI_SURFACE
	if s == State.DISABLED:
		return sb
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = DS.SHADOW_PRESSED_OFFSET
	sb.shadow_size = DS.SHADOW_PRESSED_SIZE
	if s == State.FOCUS or s == State.ERROR:
		sb.border_color = DS.DANGER if s == State.ERROR else DS.PETAL_YELLOW
		sb.set_border_width_all(DS.STROKE_FOCUS)
	return sb
