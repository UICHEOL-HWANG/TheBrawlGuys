class_name TouchStick
extends Control
## Floating virtual stick visual (design.md DS-CMP-03): hidden until a thumb lands, then a
## translucent cream base with a solid cream knob. Drawing only; TouchStickModel holds the math.

const KNOB_RATIO := 0.45
const PREVIEW_RADIUS := 140.0
const PREVIEW_SIZE_RATIO := 2.6

var _shown: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _radius: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_stick(center: Vector2, knob: Vector2, radius: float) -> void:
	_shown = true
	_center = center - global_position
	_knob = knob - global_position
	_radius = radius
	queue_redraw()


func hide_stick() -> void:
	_shown = false
	queue_redraw()


func set_preview() -> void:
	custom_minimum_size = Vector2.ONE * PREVIEW_RADIUS * PREVIEW_SIZE_RATIO
	var mid := custom_minimum_size * 0.5
	_shown = true
	_center = mid
	_knob = mid + Vector2(PREVIEW_RADIUS * 0.5, -PREVIEW_RADIUS * 0.3)
	_radius = PREVIEW_RADIUS
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	draw_circle(_center, _radius, DS.UI_SURFACE_50)
	draw_circle(_knob, _radius * KNOB_RATIO, DS.UI_SURFACE)
