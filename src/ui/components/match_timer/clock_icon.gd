class_name ClockIcon
extends Control
## The MatchTimer's clock face (design.md DS-CMP-20): a cream disc with a deep-teal rim and two
## hands, drawn from tokens; the hand turns once a minute so the clock reads as running.

const RIM := DS.S1

var _seconds: int = 0


func _init(diameter: float = DS.S7) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_seconds(seconds: int) -> void:
	_seconds = seconds
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - RIM
	draw_circle(c, r, DS.UI_SURFACE)
	draw_arc(c, r, 0.0, TAU, 32, DS.UI_TEXT, RIM, true)
	var minute := -PI * 0.5 + TAU * float(_seconds % 60) / 60.0
	draw_line(c, c + Vector2.from_angle(minute) * r * 0.75, DS.DANGER, RIM, true)
	draw_line(c, c + Vector2.from_angle(-PI * 0.5) * r * 0.5, DS.UI_TEXT, RIM, true)
