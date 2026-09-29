class_name TouchButton
extends Control
## Touch action button v2 (design.md DS-CMP-04): idle, pressed, highlight (context: petal-yellow
## ring with a soft pulse), disabled and charging (an arc filling from petal yellow to campfire
## orange, glowing when full). Circle hit-test, cream 70% fill (50% when dim_when_idle), press
## squish, icon plus a small label.

enum State { IDLE, PRESSED, HIGHLIGHT, DISABLED, CHARGING }

const PREVIEW_DIAMETER := 150.0
const ICON_RATIO := 0.32
const LABEL_OFFSET_RATIO := 0.62
const RING_WIDTH := DS.STROKE_FOCUS * 2
const PULSE_HZ := 1.5
const PULSE_SCALE := 0.04
const ARC_SEGMENTS := 48

@export var label_text: String = "공격"
@export var diameter: float = PREVIEW_DIAMETER
@export var icon: int = TouchIcons.Icon.ATTACK
## Grab rests fainter until it has something to act on (design.md DS-LAY-01).
@export var dim_when_idle: bool = false

var _state: int = State.IDLE
var _charge: float = 0.0
var _font: Font
var _pulse_time: float = 0.0


func _ready() -> void:
	_font = load(DS.FONT_CAPTION_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size()


func _process(delta: float) -> void:
	if _state != State.HIGHLIGHT:
		return
	_pulse_time += delta
	scale = Vector2.ONE * (1.0 + PULSE_SCALE * sin(_pulse_time * TAU * PULSE_HZ))


func set_state(s: int) -> void:
	if s == _state:
		return  # keep the pulse running and skip the redraw
	_state = s
	_pulse_time = 0.0
	scale = DS.PRESS_SQUISH if s == State.PRESSED or s == State.CHARGING else Vector2.ONE
	queue_redraw()


func state() -> int:
	return _state


func set_charge(value: float) -> void:
	_charge = clampf(value, 0.0, 1.0)
	queue_redraw()


func charge() -> float:
	return _charge


func contains(point: Vector2) -> bool:
	return point.distance_to(get_global_rect().get_center()) <= diameter * 0.5


func set_diameter(d: float) -> void:
	diameter = d
	_apply_size()


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	diameter = PREVIEW_DIAMETER
	_apply_size()
	set_state(State.HIGHLIGHT)


func _apply_size() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var r := diameter * 0.5
	var c := Vector2(r, r)
	draw_circle(c, r, _fill())
	match _state:
		State.HIGHLIGHT:
			draw_arc(c, r - RING_WIDTH * 0.5, 0.0, TAU, ARC_SEGMENTS, DS.PETAL_YELLOW, RING_WIDTH, true)
		State.CHARGING:
			var color := DS.GLOW if _charge >= 1.0 else DS.PETAL_YELLOW.lerp(DS.FIRE, _charge)
			draw_arc(c, r - RING_WIDTH * 0.5, -PI * 0.5, -PI * 0.5 + TAU * maxf(_charge, 0.01),
					ARC_SEGMENTS, color, RING_WIDTH, true)
	var ink := DS.UI_TEXT_SOFT if _state == State.DISABLED else DS.UI_TEXT
	TouchIcons.draw(self, icon, c - Vector2(0, r * 0.12), r * ICON_RATIO * 2.0, ink)
	if _font != null:
		draw_string(_font, Vector2(0.0, r + r * LABEL_OFFSET_RATIO), label_text,
				HORIZONTAL_ALIGNMENT_CENTER, diameter, DS.SIZE_CAPTION, ink)


func _fill() -> Color:
	match _state:
		State.PRESSED, State.CHARGING:
			return DS.UI_SURFACE_DIM
		State.DISABLED:
			return DS.UI_SURFACE_50
		State.IDLE:
			return DS.UI_SURFACE_50 if dim_when_idle else DS.UI_SURFACE_70
	return DS.UI_SURFACE_70
