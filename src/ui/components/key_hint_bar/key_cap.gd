class_name KeyCap
extends Control
## One keycap of the KeyHintBar (design.md DS-CMP-16): a translucent cream cap (ui_surface 70%)
## with a soft bottom lip, the bound key's name or an arrow drawn in code. idle · pressed:
## pressed fills with the accent (player color) and squishes (PRESS_SQUISH, motion_fast); the
## release fades the color back (motion_base) and springs back (motion_squish). ready (the special
## cap while the gauge is full, PRD-STYLE-04) adds a `fire` ring around the cap in either state.

enum State { IDLE, PRESSED }

## Action caps are s7 tall; move caps (arrows, or WASD letters for P2) are smaller so the cluster
## stays compact and every player's bar has the same height.
const HEIGHT := DS.S7
const ARROW_SIZE := DS.S6 + DS.S1
const TEXT_PAD := DS.S3
const LIP := DS.S1
const ARROW_STROKE := DS.S1
const ARROW_RATIO := 0.28
## Ready ring: stroke width and gap outside the cap.
const READY_STROKE := DS.S1
const READY_GAP := DS.S1

@export var key_text: String = "Z"
## Non-zero: draw this arrow instead of the text.
@export var arrow: Vector2 = Vector2.ZERO
@export var accent: Color = DS.UI_ACCENT
## Move-cluster cap: ARROW_SIZE tall even when it shows a letter.
@export var small: bool = false

var fill_amount: float = 0.0:
	set(v):
		fill_amount = v
		queue_redraw()

var _state: int = State.IDLE
var _ready_ring: bool = false
var _font: Font
var _tween: Tween


func _ready() -> void:
	_font = load(DS.FONT_BODY_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _min_size()
	resized.connect(func() -> void: pivot_offset = Vector2(size.x * 0.5, size.y))


func set_state(s: int) -> void:
	if s == _state:
		return
	_state = s
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var pressed := s == State.PRESSED
	if not is_inside_tree():
		fill_amount = 1.0 if pressed else 0.0
		scale = DS.PRESS_SQUISH if pressed else Vector2.ONE
		return
	_tween = UiMotion.parallel(self)
	if pressed:
		scale = DS.PRESS_SQUISH
		UiMotion.step(_tween, self, "fill_amount", 1.0, UiMotion.Token.FAST)
	else:
		UiMotion.step(_tween, self, "scale", Vector2.ONE, UiMotion.Token.SQUISH)
		UiMotion.step(_tween, self, "fill_amount", 0.0, UiMotion.Token.BASE)


func state() -> int:
	return _state


func set_ready(on: bool) -> void:
	if on != _ready_ring:
		_ready_ring = on
		queue_redraw()


func is_ready() -> bool:
	return _ready_ring


func fill() -> float:
	return fill_amount


func _min_size() -> Vector2:
	if arrow != Vector2.ZERO:
		return Vector2(ARROW_SIZE, ARROW_SIZE)
	var h := float(ARROW_SIZE if small else HEIGHT)
	var w := h
	if _font != null:
		w = maxf(w, _font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DS.SIZE_CAPTION).x + TEXT_PAD * 2)
	return Vector2(w, h)


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(DS.RADIUS_S)
	sb.bg_color = DS.UI_SURFACE_70.lerp(accent, fill_amount)
	sb.border_color = DS.UI_SHADOW
	sb.border_width_bottom = roundi(LIP * (1.0 - fill_amount))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if _ready_ring:
		_draw_ready_ring()
	var ink := DS.UI_TEXT.lerp(DS.UI_SURFACE, fill_amount)
	if arrow != Vector2.ZERO:
		_draw_arrow(ink)
	elif _font != null:
		var baseline := (size.y + _font.get_ascent(DS.SIZE_CAPTION) - _font.get_descent(DS.SIZE_CAPTION)) * 0.5
		draw_string(_font, Vector2(0.0, baseline), key_text, HORIZONTAL_ALIGNMENT_CENTER, size.x,
				DS.SIZE_CAPTION, ink)


func _draw_ready_ring() -> void:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(DS.RADIUS_S + READY_GAP)
	ring.set_border_width_all(READY_STROKE)
	ring.border_color = DS.FIRE
	draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(READY_GAP + READY_STROKE))


## A soft arrow: a round-ended stem with a chevron head (no sharp spikes, design.md §3).
func _draw_arrow(ink: Color) -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * ARROW_RATIO
	var tip := c + arrow * r
	var side := Vector2(-arrow.y, arrow.x) * r * 0.7
	draw_line(c - arrow * r, tip, ink, ARROW_STROKE, true)
	draw_polyline(PackedVector2Array([tip - arrow * r * 0.7 + side, tip, tip - arrow * r * 0.7 - side]),
			ink, ARROW_STROKE, true)

