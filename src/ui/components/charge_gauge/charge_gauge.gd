class_name ChargeGauge
extends Control
## Heavy-attack charge gauge (design.md DS-CMP-05): a small cream pill above the fighter's head
## that fills from petal yellow to campfire orange and glows when the charge is full.

const WIDTH := DS.S8 + DS.S6
const HEIGHT := DS.S4
const PREVIEW_VALUE := 0.7

var _value: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size


func set_value(v: float) -> void:
	_value = clampf(v, 0.0, 1.0)
	queue_redraw()


func value() -> float:
	return _value


func is_full() -> bool:
	return _value >= 1.0


func fill_color() -> Color:
	return DS.GLOW if is_full() else DS.PETAL_YELLOW.lerp(DS.FIRE, _value)


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	set_value(PREVIEW_VALUE)


func _draw() -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = DS.UI_SURFACE_70
	back.set_corner_radius_all(DS.RADIUS_PILL)
	back.shadow_color = DS.UI_SHADOW
	back.shadow_size = DS.SHADOW_PRESSED_SIZE
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	if _value <= 0.0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color()
	fill.set_corner_radius_all(DS.RADIUS_PILL)
	var inset := float(DS.S1) * 0.5
	draw_style_box(fill, Rect2(Vector2(inset, inset), Vector2((size.x - inset * 2.0) * _value, size.y - inset * 2.0)))
