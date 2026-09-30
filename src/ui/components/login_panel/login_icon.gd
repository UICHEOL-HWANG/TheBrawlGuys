class_name LoginIcon
extends Control
## Small vector marks for the login card (design.md DS-CMP-14), drawn in code so no third-party
## art is shipped: a globe for the language link, and the Google "G" (brand colors only on the G,
## as Google's sign-in branding asks). The card's emblem is the CrestLogo (DS-CMP-15).

enum Icon { GLOBE }

const ARC_POINTS := 24
## Google G arcs in radians (0 = +x, clockwise on screen); the gap is the top-right opening.
const G_ARCS: Array[Array] = [
	[-0.05, 0.85, DS.GOOGLE_BLUE], [0.85, 2.35, DS.GOOGLE_GREEN],
	[2.35, 3.55, DS.GOOGLE_YELLOW], [3.55, 5.45, DS.GOOGLE_RED],
]
const G_STROKE_RATIO := 0.36

@export var icon: Icon = Icon.GLOBE
@export var tint: Color = DS.UI_SURFACE


func _init(p_icon: Icon = Icon.GLOBE, p_size: float = DS.S5) -> void:
	icon = p_icon
	custom_minimum_size = Vector2.ONE * p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_draw_globe(size * 0.5, minf(size.x, size.y) * 0.5)


static func draw_google_g(ci: CanvasItem, center: Vector2, radius: float) -> void:
	var width := radius * G_STROKE_RATIO
	var ring := radius - width * 0.5
	for arc: Array in G_ARCS:
		ci.draw_arc(center, ring, float(arc[0]), float(arc[1]), ARC_POINTS, arc[2] as Color, width, true)
	var bar := Rect2(center + Vector2(0.0, -width * 0.5), Vector2(radius, width))
	ci.draw_rect(bar, DS.GOOGLE_BLUE)


func _draw_globe(c: Vector2, r: float) -> void:
	var w := maxf(r * 0.14, 1.5)
	draw_arc(c, r - w, 0.0, TAU, ARC_POINTS, tint, w, true)
	draw_line(c + Vector2(-r + w, 0.0), c + Vector2(r - w, 0.0), tint, w, true)
	var meridian := PackedVector2Array()
	for i: int in ARC_POINTS + 1:
		var a := TAU * i / ARC_POINTS
		meridian.append(c + Vector2(cos(a) * r * 0.42, sin(a) * (r - w)))
	draw_polyline(meridian, tint, w, true)
