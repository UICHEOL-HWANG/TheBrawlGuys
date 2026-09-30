class_name GimmickIcon
extends Control
## Arena gimmick icon on a SelectCard (design.md DS-CMP-08, DS-VIS-04 hazard colors): a soft
## badge with a round-form glyph — water (ring-out lake/river), fire (campfire), crack (breaking
## planks), bounce (mushroom with an up arrow), fog (cloud). Code-drawn, any size.

const KINDS: Array[String] = ["water", "fire", "crack", "bounce", "fog"]
const SEGMENTS := 20

@export var kind: String = "fire":
	set(value):
		kind = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * DS.CARD_ICON
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, DS.UI_SURFACE_DIM)
	var s := r * 0.62
	match kind:
		"water":
			_waves(c, s)
		"fire":
			_flame(c, s)
		"crack":
			_crack(c, s)
		"bounce":
			_bounce(c, s)
		"fog":
			_fog(c, s)


func _waves(c: Vector2, s: float) -> void:
	for k: int in 2:
		var pts := PackedVector2Array()
		for i: int in SEGMENTS + 1:
			var t := float(i) / SEGMENTS
			pts.append(c + Vector2((t - 0.5) * 2.0 * s, (k - 0.5) * s * 0.8 + sin(t * TAU * 1.5) * s * 0.18))
		draw_polyline(pts, DS.WATER, maxf(s * 0.22, 2.0), true)


func _flame(c: Vector2, s: float) -> void:
	var outer := _teardrop(c + Vector2(0, s * 0.15), s * 0.7, s * 1.05)
	draw_colored_polygon(outer, DS.FIRE)
	draw_colored_polygon(_teardrop(c + Vector2(0, s * 0.4), s * 0.36, s * 0.55), DS.GLOW)


func _crack(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c - Vector2(s, s * 0.45), Vector2(s * 2.0, s * 0.9)), DS.DIRT)
	var zig := PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.45), c + Vector2(s * 0.15, -s * 0.1),
		c + Vector2(-s * 0.1, s * 0.15), c + Vector2(s * 0.2, s * 0.45)])
	draw_polyline(zig, DS.CANOPY_DEEP, maxf(s * 0.18, 2.0), true)


func _bounce(c: Vector2, s: float) -> void:
	var cap := PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var a := PI + PI * float(i) / SEGMENTS
		cap.append(c + Vector2(cos(a) * s, sin(a) * s * 0.7 + s * 0.55))
	draw_colored_polygon(cap, DS.PETAL_PINK)
	draw_circle(c + Vector2(-s * 0.35, s * 0.2), s * 0.14, DS.GLOW)
	var w := maxf(s * 0.2, 2.0)
	draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.35), c + Vector2(0, -s * 0.8),
		c + Vector2(s * 0.4, -s * 0.35)]), DS.PETAL_YELLOW, w, true)


func _fog(c: Vector2, s: float) -> void:
	for p: Vector3 in [Vector3(-0.45, 0.1, 0.42), Vector3(0.0, -0.15, 0.55), Vector3(0.45, 0.1, 0.42)]:
		draw_circle(c + Vector2(p.x, p.y) * s, p.z * s, DS.UI_TEXT_SOFT)
	draw_rect(Rect2(c + Vector2(-s * 0.85, s * 0.1), Vector2(s * 1.7, s * 0.42)), DS.UI_TEXT_SOFT)
	for k: int in 2:
		var y := c.y + s * (0.75 + k * 0.28)
		draw_line(Vector2(c.x - s * 0.7, y), Vector2(c.x + s * 0.7, y), DS.UI_TEXT_SOFT, maxf(s * 0.12, 1.5), true)


## A flame-shaped drop: a round belly of radius w around `belly`, pointed tip h above it.
func _teardrop(belly: Vector2, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var a := PI * float(i) / SEGMENTS  # right, through the bottom (screen y down), to the left
		pts.append(belly + Vector2(cos(a) * w, sin(a) * w))
	pts.append(belly + Vector2(-w * 0.7, -h * 0.45))
	pts.append(belly + Vector2(0, -h))
	pts.append(belly + Vector2(w * 0.7, -h * 0.45))
	return pts
