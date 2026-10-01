class_name ComboBadge
extends Control
## The PlayerCard's "N연타" burst (design.md DS-CMP-22): a small spiky star (petal yellow, fire
## rim) with the count in Jua over it, pinned to the card's inner top corner (the bar side, away
## from the portrait). Pops when the count changes; hidden under 2 hits.

const POINTS := 10
const INNER := 0.62
const POP := 1.3

var _label: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	_label.add_theme_color_override("font_color", DS.UI_TEXT)
	add_child(_label)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## hits < 2 hides the badge.
func set_hits(hits: int) -> void:
	var was := visible
	visible = hits >= 2
	if not visible:
		return
	var text := "%d연타" % hits
	if text != _label.text or not was:
		_label.text = text
		custom_minimum_size = _label.get_minimum_size() + Vector2(DS.S5, DS.S3)
		size = custom_minimum_size
		queue_redraw()
		if is_inside_tree():
			UiMotion.bump(self, POP)


func text() -> String:
	return _label.text if visible else ""


func _draw() -> void:
	var c := size * 0.5
	var pts := PackedVector2Array()
	for i: int in POINTS * 2:
		var r := c * (1.0 if i % 2 == 0 else INNER)
		var a := TAU * float(i) / float(POINTS * 2) - PI * 0.5
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, DS.PETAL_YELLOW)
	pts.append(pts[0])
	draw_polyline(pts, DS.FIRE, DS.S1 * 0.5, true)
