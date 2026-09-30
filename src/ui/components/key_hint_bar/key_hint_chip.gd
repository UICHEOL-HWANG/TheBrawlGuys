class_name KeyHintChip
extends Control
## The KeyHintBar's hide/show chip (design.md DS-CMP-16): a small cream pill with an eye drawn in
## code and "키 숨기기" / "키 보기" (eye crossed out while the keys are hidden). Hover draws the
## petal-yellow focus ring; a left click emits pressed.

signal pressed

const HIDE_TEXT := "키 숨기기"
const SHOW_TEXT := "키 보기"
const HEIGHT := DS.S6 + DS.S2
const ICON_W := DS.S5
const PAD := DS.S3
const STROKE := DS.S1 * 0.5
const SEGMENTS := 16
## How far each eyelid arc's center sits off the eye's axis, relative to the eye's half width.
const LID_OFFSET := 0.9

var _shown: bool = true
var _hover: bool = false
var _font: Font


func _ready() -> void:
	_font = load(DS.FONT_CAPTION_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))
	_fit()


func set_shown(on: bool) -> void:
	_shown = on
	_fit()


func text() -> String:
	return HIDE_TEXT if _shown else SHOW_TEXT


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		accept_event()
		pressed.emit()


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _fit() -> void:
	var w := ICON_W + PAD * 3.0
	if _font != null:
		w += _font.get_string_size(text(), HORIZONTAL_ALIGNMENT_LEFT, -1, DS.SIZE_CAPTION).x
	custom_minimum_size = Vector2(w, HEIGHT)
	queue_redraw()


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(DS.RADIUS_PILL)
	sb.bg_color = DS.UI_SURFACE_70
	if _hover:
		sb.border_color = DS.PETAL_YELLOW
		sb.set_border_width_all(DS.STROKE_FOCUS)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	_draw_eye(Vector2(PAD + ICON_W * 0.5, size.y * 0.5), ICON_W * 0.5, DS.UI_TEXT)
	if _font != null:
		var baseline := (size.y + _font.get_ascent(DS.SIZE_CAPTION) - _font.get_descent(DS.SIZE_CAPTION)) * 0.5
		draw_string(_font, Vector2(PAD * 2.0 + ICON_W, baseline), text(), HORIZONTAL_ALIGNMENT_LEFT,
				-1, DS.SIZE_CAPTION, DS.UI_TEXT)


## An almond eye (two soft arcs + pupil); crossed out while the keys are hidden.
func _draw_eye(c: Vector2, r: float, ink: Color) -> void:
	# each lid is an arc through the eye corners c ± (r, 0), centered off-axis by d
	var d := r * LID_OFFSET
	var bend := Vector2(r, d).length()
	var a := atan2(d, r)
	draw_arc(c + Vector2(0, d), bend, -PI + a, -a, SEGMENTS, ink, STROKE, true)
	draw_arc(c - Vector2(0, d), bend, a, PI - a, SEGMENTS, ink, STROKE, true)
	draw_circle(c, r * 0.32, ink)
	if not _shown:
		draw_line(c + Vector2(-r, r * 0.8), c + Vector2(r, -r * 0.8), ink, STROKE, true)
