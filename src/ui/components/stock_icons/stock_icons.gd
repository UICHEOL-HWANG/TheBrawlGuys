class_name StockIcons
extends HBoxContainer
## Remaining stocks (design.md DS-CMP-02): one player marker per stock, lost ones dimmed.
## Unlimited (the tutorial's practice arena, which refills its stocks): one marker and "∞" in
## the card's caption Jua, so 99 stocks never read as the configured three.

const LOST_POP := 1.4
const INFINITY := "∞"

## Right-hand HUD cards read outside-in: "∞" before the marker, mirroring the left cards.
var mirrored: bool = false
var _unlimited: bool = false
var _infinity: Label = null


## diameter: marker size (the HUD PlayerCard uses smaller pips).
func setup(index: int, max_stocks: int, diameter: float = DS.S5) -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_infinity = null
	add_theme_constant_override("separation", DS.S2)
	for i: int in max_stocks:
		var m := PlayerMarker.new()
		m.setup(index, diameter)
		add_child(m)
	if _unlimited:
		set_unlimited(true)


## Team mode: every marker in the team color (null = the player color).
func set_tint(c: Variant) -> void:
	for m: PlayerMarker in _markers():
		m.set_tint(c)


## Endless stocks: the first marker (never dimmed) and "∞" instead of the pips.
func set_unlimited(on: bool) -> void:
	_unlimited = on
	var markers := _markers()
	for i: int in markers.size():
		markers[i].visible = not on or i == 0
		if on:
			markers[i].set_dimmed(false)
	if on and _infinity == null:
		_infinity = _infinity_label()
		add_child(_infinity)
		move_child(_infinity, 0 if mirrored else -1)
	if _infinity != null:
		_infinity.visible = on


func is_unlimited() -> bool:
	return _unlimited


## "∞" while unlimited, else "".
func infinity_text() -> String:
	return INFINITY if _unlimited and _infinity != null else ""


func set_stocks(n: int) -> void:
	if _unlimited:
		return
	var markers := _markers()
	for i: int in markers.size():
		var losing := i >= n and not markers[i].is_dimmed()
		markers[i].set_dimmed(i >= n)
		if losing and is_inside_tree():
			UiMotion.bump(markers[i], LOST_POP)


func shown() -> int:
	var count := 0
	for m: PlayerMarker in _markers():
		if not m.is_dimmed():
			count += 1
	return count


func set_preview() -> void:
	setup(1, 3)
	set_stocks(2)


func _markers() -> Array[PlayerMarker]:
	var out: Array[PlayerMarker] = []
	for child: Node in get_children():
		if child is PlayerMarker:
			out.append(child as PlayerMarker)
	return out


static func _infinity_label() -> Label:
	var l := Label.new()
	l.text = INFINITY
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
