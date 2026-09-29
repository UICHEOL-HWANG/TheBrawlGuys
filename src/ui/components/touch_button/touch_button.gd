class_name TouchButton
extends Control
## Touch action button v1 (design.md DS-CMP-04): idle / pressed. Highlight, disabled and
## charging states arrive with v2 in Phase 2. Circle hit-test, cream 70% fill, press squish.

enum State { IDLE, PRESSED }

const PREVIEW_DIAMETER := 150.0
## Vertical nudge that centers a body-size label inside the circle.
const LABEL_BASELINE_RATIO := 0.35

@export var label_text: String = "공격"
@export var diameter: float = PREVIEW_DIAMETER

var _state: int = State.IDLE
var _font: Font


func _ready() -> void:
	_font = load(DS.FONT_BODY_PATH) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size()


func set_state(s: int) -> void:
	_state = s
	scale = DS.PRESS_SQUISH if s == State.PRESSED else Vector2.ONE
	queue_redraw()


func contains(point: Vector2) -> bool:
	return point.distance_to(get_global_rect().get_center()) <= diameter * 0.5


func set_preview() -> void:
	diameter = PREVIEW_DIAMETER
	_apply_size()


func _apply_size() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var r := diameter * 0.5
	var fill := DS.UI_SURFACE_DIM if _state == State.PRESSED else DS.UI_SURFACE_70
	draw_circle(Vector2(r, r), r, fill)
	if _font != null:
		draw_string(_font, Vector2(0.0, r + DS.SIZE_BODY * LABEL_BASELINE_RATIO), label_text,
				HORIZONTAL_ALIGNMENT_CENTER, diameter, DS.SIZE_BODY, DS.UI_TEXT)


## Resizes the button (layouts change sizes at runtime).
func set_diameter(d: float) -> void:
	diameter = d
	_apply_size()
