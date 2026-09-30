class_name CardMarks
extends HBoxContainer
## Whose cursor is on a SelectCard (design.md DS-CMP-08 + DS-VIS-03): one pill badge per player —
## the player's marker (color + shape) and number ("P1") on the card surface — overlaid on the
## thumbnail's top-right corner (the card adds it beside its content), so it takes no height and
## cards never jump. Arena cards leave it empty.

const MARKER := DS.S5
const PILL_PAD := DS.S2

var _players: Array[int] = []


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", DS.S2)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_players(players: Array[int]) -> void:
	if players == _players:
		return
	_players = players.duplicate()
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	for index: int in _players:
		add_child(_badge(index))


func players() -> Array[int]:
	return _players


static func _badge(index: int) -> Control:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = DS.UI_SURFACE
	box.set_corner_radius_all(DS.RADIUS_PILL)
	box.set_content_margin_all(PILL_PAD)
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var marker := PlayerMarker.new()
	marker.setup(index, MARKER)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marker)
	var label := Label.new()
	label.text = PlayerStyle.label(index)
	label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	label.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	label.add_theme_color_override("font_color", DS.UI_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return pill
