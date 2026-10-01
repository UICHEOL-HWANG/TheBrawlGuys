class_name CardBar
extends Control
## A PlayerCard bar (design.md DS-CMP-22): a rounded track (BAR_TRACK) with a fill.
## DAMAGE: thick, fills with the damage % (full at FULL_PERCENT) in DAMAGE_BAR_RAMP green ->
## yellow -> red (the PlayerCard prints the % on its name line). GAUGE: thin, the special gauge in
## GAUGE_BAR, flashing (alpha pulse) while full. Colors are DS tokens (design.md "대미지 바 램프").

enum Kind { DAMAGE, GAUGE }

const FULL_PERCENT := 150.0
const DAMAGE_BAR_RAMP := [DS.GRASS_MID, DS.PETAL_YELLOW, DS.FIRE, DS.DANGER]
const BAR_TRACK := DS.UI_SURFACE_DIM
const GAUGE_BAR := DS.PETAL_BLUE
const FLASH_HZ := 3.0
const FLASH_LOW := 0.45

var _kind: int = Kind.DAMAGE
var _ratio: float = 0.0
var _color: Color = DS.GRASS_MID
var _full: bool = false


func _init(kind: int = Kind.DAMAGE, width: float = DS.CARD_WIDTH) -> void:
	_kind = kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, DS.S3 if kind == Kind.DAMAGE else DS.S1)


func set_width(width: float) -> void:
	custom_minimum_size.x = width


func set_percent(p: float) -> void:
	_ratio = clampf(p / FULL_PERCENT, 0.0, 1.0)
	_color = DamageColor.for_percent(p, DAMAGE_BAR_RAMP)
	queue_redraw()


## Special gauge share 0..1; full starts the flash.
func set_gauge(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_color = GAUGE_BAR
	_full = _ratio >= 1.0
	if not _full:
		modulate.a = 1.0
	queue_redraw()


func ratio() -> float:
	return _ratio


func is_flashing() -> bool:
	return _full


func _process(_delta: float) -> void:
	if _full:
		var phase := Time.get_ticks_msec() / 1000.0 * FLASH_HZ * TAU
		modulate.a = lerpf(FLASH_LOW, 1.0, 0.5 + 0.5 * sin(phase))


func _draw() -> void:
	var radius := int(size.y * 0.5)
	var track := StyleBoxFlat.new()
	track.bg_color = BAR_TRACK
	track.set_corner_radius_all(radius)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	if _ratio <= 0.0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color
	fill.set_corner_radius_all(radius)
	draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.x * _ratio, size.y), size.y)))
