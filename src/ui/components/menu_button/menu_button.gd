class_name UiMenuButton
extends Button
## Menu button (design.md DS-CMP-06): a pill in the campfire accent (primary) or cream surface
## (secondary). States idle · focus (petal-yellow ring, also on hover) · pressed (squish +
## pressed shadow) · disabled (dim surface, soft text). Named UiMenuButton because Godot already
## has a MenuButton class.

enum State { IDLE, FOCUS, PRESSED, DISABLED }
enum Kind { PRIMARY, SECONDARY }

@export var kind: Kind = Kind.PRIMARY

var _state: int = State.IDLE
var _release_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(DS.BUTTON_MIN_WIDTH, DS.BUTTON_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", load(DS.FONT_BODY_PATH) as Font)
	add_theme_font_size_override("font_size", DS.SIZE_BODY)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	focus_entered.connect(func() -> void: _follow(State.FOCUS))
	focus_exited.connect(func() -> void: _follow(State.IDLE))
	mouse_entered.connect(func() -> void: _follow(State.FOCUS))
	mouse_exited.connect(func() -> void: _follow(State.FOCUS if has_focus() else State.IDLE))
	button_down.connect(func() -> void: set_state(State.PRESSED))
	button_up.connect(func() -> void: set_state(State.FOCUS if has_focus() else State.IDLE))
	_apply()


func set_state(s: int) -> void:
	var was_pressed := _state == State.PRESSED
	_state = s
	disabled = s == State.DISABLED
	if _release_tween != null and _release_tween.is_valid():
		_release_tween.kill()
	pivot_offset = size * 0.5
	if s == State.PRESSED:
		scale = DS.PRESS_SQUISH
	elif was_pressed and is_inside_tree():
		_release_tween = UiMotion.release(self)
	else:
		scale = Vector2.ONE
	_apply()


func state() -> int:
	return _state


func set_kind(k: Kind) -> void:
	kind = k
	_apply()


func set_preview() -> void:
	text = "봇 대전"


## Focus/hover changes never override pressed or disabled.
func _follow(s: int) -> void:
	if _state == State.PRESSED or _state == State.DISABLED:
		return
	set_state(s)


func _apply() -> void:
	var box := _box(_state)
	for style: String in ["normal", "hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(style, box)
	add_theme_stylebox_override("disabled", _box(State.DISABLED))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		add_theme_color_override(color, DS.UI_TEXT)
	add_theme_color_override("font_disabled_color", DS.UI_TEXT_SOFT)


func _box(s: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(DS.RADIUS_PILL)
	sb.content_margin_left = DS.S6
	sb.content_margin_right = DS.S6
	sb.content_margin_top = DS.S3
	sb.content_margin_bottom = DS.S3
	sb.bg_color = DS.UI_ACCENT if kind == Kind.PRIMARY else DS.UI_SURFACE
	if s == State.DISABLED:
		sb.bg_color = DS.UI_SURFACE_DIM
		return sb
	sb.shadow_color = DS.UI_SHADOW
	var pressed := s == State.PRESSED
	sb.shadow_offset = DS.SHADOW_PRESSED_OFFSET if pressed else DS.SHADOW_SOFT_OFFSET
	sb.shadow_size = DS.SHADOW_PRESSED_SIZE if pressed else DS.SHADOW_SOFT_SIZE
	if s == State.FOCUS:
		sb.border_color = DS.PETAL_YELLOW
		sb.set_border_width_all(DS.STROKE_FOCUS)
	return sb
