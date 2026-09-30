class_name PadGlyph
extends Control
## A gamepad button prompt (design.md DS-TOK-06 입력 장치 프롬프트), drawn in code on the 64 grid
## with round ends: a face button badge (Xbox "A" / "B" letters, PlayStation cross / circle) or
## the d-pad (a soft plus with its left and right arms filled). Same height as a small KeyCap.

const STROKE_RATIO := 0.09

@export var glyph: String = SelectPrompts.GLYPH_A:
	set(value):
		glyph = value
		queue_redraw()

var _font: Font


func _ready() -> void:
	_font = load(DS.FONT_BODY_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * KeyCap.ARROW_SIZE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if glyph == SelectPrompts.GLYPH_DPAD:
		_dpad(c, r)
		return
	draw_circle(c, r, DS.UI_SURFACE_70)
	draw_arc(c, r - 1.0, 0.0, TAU, 32, DS.UI_SHADOW, 2.0, true)
	var w := maxf(r * STROKE_RATIO * 2.0, 2.0)
	match glyph:
		SelectPrompts.GLYPH_CROSS:
			var d := r * 0.38
			draw_line(c - Vector2(d, d), c + Vector2(d, d), DS.UI_TEXT, w, true)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), DS.UI_TEXT, w, true)
		SelectPrompts.GLYPH_CIRCLE:
			draw_arc(c, r * 0.42, 0.0, TAU, 24, DS.UI_TEXT, w, true)
		_:
			_letter(c, glyph.to_upper())


func _letter(c: Vector2, text: String) -> void:
	if _font == null:
		return
	var baseline := c.y + (_font.get_ascent(DS.SIZE_CAPTION) - _font.get_descent(DS.SIZE_CAPTION)) * 0.5
	draw_string(_font, Vector2(0.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, DS.SIZE_CAPTION,
			DS.UI_TEXT)


## A soft plus: the vertical arm in the cap color, the horizontal arms (browse) in ink.
func _dpad(c: Vector2, r: float) -> void:
	var arm := r * 0.36
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(arm * 0.5))
	sb.bg_color = DS.UI_SURFACE_70
	draw_style_box(sb, Rect2(c - Vector2(arm, r), Vector2(arm * 2.0, r * 2.0)))
	sb.bg_color = DS.UI_TEXT
	draw_style_box(sb, Rect2(c - Vector2(r, arm), Vector2(r * 2.0, arm * 2.0)))
	draw_circle(c, arm * 0.5, DS.UI_SURFACE_70)
