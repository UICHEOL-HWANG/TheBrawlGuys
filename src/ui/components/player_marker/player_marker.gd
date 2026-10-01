class_name PlayerMarker
extends Control
## A player's color + shape badge (design.md DS-VIS-03), shared by HUD components.
## Dimmed markers (lost stocks) are drawn as a soft outline with a small pop.

const POP_SCALE := 1.4

var _index: int = 0
var _diameter: float = DS.S6
var _dimmed: bool = false
## Team mode draws the shape in the team color (set_tint); null = the player color.
var _tint: Variant = null


func setup(index: int, diameter: float) -> void:
	_index = index
	_diameter = diameter
	custom_minimum_size = Vector2(diameter, diameter)
	pivot_offset = custom_minimum_size * 0.5
	queue_redraw()


func set_dimmed(d: bool) -> void:
	if d and not _dimmed and is_inside_tree():
		UiMotion.bump(self, POP_SCALE)
	_dimmed = d
	queue_redraw()


func set_tint(c: Variant) -> void:
	_tint = c
	queue_redraw()


func is_dimmed() -> bool:
	return _dimmed


func _draw() -> void:
	var pts := PlayerStyle.polygon(PlayerStyle.shape(_index), _diameter * 0.5, size * 0.5)
	if _dimmed:
		# Lost stock: outline only, so it stays visible on any background.
		pts.append(pts[0])
		draw_polyline(pts, DS.UI_TEXT_SOFT, DS.S1)
	else:
		draw_colored_polygon(pts, _tint if _tint != null else PlayerStyle.color(_index))
