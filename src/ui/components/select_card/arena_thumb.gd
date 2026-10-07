class_name ArenaThumb
extends Control
## Stylised top-down diorama of an arena for a SelectCard (design.md DS-CMP-08 디오라마 썸네일):
## the meadow, ring-out water, the floors lifted over a dirt band, a ring of trees and each
## gimmick as a token-colored marker. Fed plain data (set_diorama) — never reads the game.
## Data: {extent: float (world half size shown), ground, floor, rim, water, canopy: Color,
## floors / zones: Array of ArenaShape.to_view(), gimmicks: Array of {kind, pos: Vector3, radius}}.

const RIM_DROP := 5.0
const TREE_COUNT := 10
const TREE_RADIUS := 0.09
const MARKER_RADIUS := 0.07
const RING_POINTS := 64

var _data: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(DS.CARD_WIDTH - DS.S5 * 2, DS.CARD_THUMB_HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_diorama(data: Dictionary) -> void:
	_data = data
	queue_redraw()


func diorama() -> Dictionary:
	return _data


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _color("ground", DS.GRASS_MID)
	box.set_corner_radius_all(DS.RADIUS_M)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if _data.is_empty():
		return
	for z: Dictionary in _data.get("zones", []):
		_shape(z, _color("water", DS.WATER), Vector2.ZERO)
	_trees()
	for f: Dictionary in _data.get("floors", []):
		_shape(f, _color("rim", DS.DIRT), Vector2(0, RIM_DROP))
	for f: Dictionary in _data.get("floors", []):
		_shape(f, _color("floor", DS.GRASS), Vector2.ZERO)
	for g: Dictionary in _data.get("gimmicks", []):
		_marker(g)


## World (x, z) to thumbnail pixels: the arena fills the height, centered.
func to_px(p: Vector3) -> Vector2:
	return size * 0.5 + Vector2(p.x, p.z) * _scale()


func _scale() -> float:
	var extent := maxf(float(_data.get("extent", 10.0)), 0.1)
	return minf(size.x, size.y) * 0.5 / extent


func _shape(s: Dictionary, color: Color, offset: Vector2) -> void:
	var at := to_px(s["center"]) + offset
	if int(s["kind"]) == ArenaShape.Kind.CIRCLE:
		draw_circle(at, float(s["radius"]) * _scale(), color)
		return
	if int(s["kind"]) == ArenaShape.Kind.RING:
		var outer := float(s["radius"])
		var inner := float(s.get("inner", 0.0))
		draw_arc(at, (outer + inner) * 0.5 * _scale(), 0.0, TAU, RING_POINTS, color, (outer - inner) * _scale(), true)
		return
	var half: Vector2 = (s["half"] as Vector2) * _scale()
	var yaw := float(s["yaw"])
	var pts := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(at + (corner * half).rotated(-yaw))
	draw_colored_polygon(pts, color)


func _trees() -> void:
	var r := minf(size.x, size.y) * 0.5
	for i: int in TREE_COUNT:
		var a := TAU * (i + 0.5) / TREE_COUNT
		var at := size * 0.5 + Vector2(cos(a) * size.x * 0.46, sin(a) * size.y * 0.46)
		draw_circle(at, r * TREE_RADIUS * (1.0 + 0.3 * (i % 3)), _color("canopy", DS.CANOPY))


func _marker(g: Dictionary) -> void:
	var r := minf(size.x, size.y) * 0.5 * MARKER_RADIUS
	var at := to_px(g.get("pos", Vector3.ZERO))
	match String(g.get("kind", "")):
		"burn_zone":
			draw_circle(at, r * 1.6, DS.FIRE)
			draw_circle(at, r * 0.8, DS.GLOW)
		"bounce_pad":
			draw_circle(at, maxf(float(g.get("radius", 1.0)) * _scale(), r * 2.0), DS.PETAL_PINK)
			draw_circle(at, r * 0.6, DS.GLOW)
		"platform":
			draw_line(at - Vector2(r * 2.0, r * 0.4), at + Vector2(r * 2.0, -r * 0.4), DS.CANOPY_DEEP, 2.0, true)
		"fog":
			for k: int in 3:
				var y := size.y * (0.3 + 0.2 * k)
				draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y), DS.FOG_VEIL, r * 1.4, true)


func _color(key: String, fallback: Color) -> Color:
	return _data.get(key, fallback) as Color
