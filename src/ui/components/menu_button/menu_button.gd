class_name UiMenuButton
extends Button
## Menu button (design.md DS-CMP-06 v2): a comic sticker key — cream face in a deep-teal outline
## with a thick bottom edge (primary), a flatter key with soft text (secondary), or a light
## outline with white text for glass cards (ghost). States idle · focus (petal-yellow face, key
## lifted, also on hover) · pressed (campfire face, key pushed down + squish) · disabled (dim
## face, flat). Named UiMenuButton because Godot already has a MenuButton class.

enum State { IDLE, FOCUS, PRESSED, DISABLED }
enum Kind { PRIMARY, SECONDARY, GHOST }

## Outline width of the ghost kind.
const GHOST_EDGE := 2

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
	var ghost := kind == Kind.GHOST
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		add_theme_color_override(color, DS.UI_SURFACE if ghost else DS.UI_TEXT)
	if kind == Kind.SECONDARY:  # quieter until focused (focus / press turn the face bright)
		add_theme_color_override("font_color", DS.UI_TEXT_SOFT if _state == State.IDLE else DS.UI_TEXT)
	add_theme_color_override("font_disabled_color", DS.UI_SURFACE_50 if ghost else DS.UI_TEXT_SOFT)


func _box(s: int) -> StyleBoxFlat:
	if kind == Kind.GHOST:
		return _ghost(_margins(StyleBoxFlat.new(), 0, 0), s)
	var depth := _depth(s)
	var sb := Sticker.box(_face(s), DS.RADIUS_M, depth)
	return _margins(sb, depth - _depth(State.IDLE), depth)


## Bottom key edge: lifted on focus, pushed down when pressed, flat when disabled.
func _depth(s: int) -> int:
	match s:
		State.FOCUS:
			return Sticker.DEPTH_FOCUS
		State.PRESSED:
			return Sticker.DEPTH_PRESSED
		State.DISABLED:
			return 0
	return Sticker.DEPTH if kind == Kind.PRIMARY else Sticker.DEPTH_PRESSED


func _face(s: int) -> Color:
	match s:
		State.FOCUS:
			return DS.PETAL_YELLOW
		State.PRESSED:
			return DS.UI_ACCENT
		State.DISABLED:
			return DS.UI_SURFACE_DIM
	return DS.UI_SURFACE


## The face moves `lift` px up (negative = down) and the label stays centered on the face (above
## the `depth` key edge); the control rect stays put so containers never re-sort.
func _margins(sb: StyleBoxFlat, lift: int, depth: int) -> StyleBoxFlat:
	sb.expand_margin_top = lift
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = Sticker.EDGE + DS.S2 - lift
	sb.content_margin_bottom = Sticker.EDGE + DS.S2 + depth
	sb.set_corner_radius_all(DS.RADIUS_M)
	return sb


## No fill and no shadow: a light edge (a focus ring when focused) over the glass.
func _ghost(sb: StyleBoxFlat, s: int) -> StyleBoxFlat:
	sb.bg_color = DS.TRANSPARENT
	var focused := s == State.FOCUS or s == State.PRESSED
	sb.border_color = DS.PETAL_YELLOW if focused else (DS.UI_SURFACE_50 if s == State.DISABLED else DS.UI_SURFACE_70)
	sb.set_border_width_all(DS.STROKE_FOCUS if focused else GHOST_EDGE)
	return sb
