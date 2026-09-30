class_name LoginIcon
extends Control
## Small vector marks for the login card (design.md DS-CMP-14), drawn in code so no third-party
## art is shipped: a leaf sprig emblem, a globe for the language link, and the Google "G"
## (brand colors only on the G, as Google's sign-in branding asks).

enum Icon { LEAF, GLOBE }

const ARC_POINTS := 24
## Google G arcs in radians (0 = +x, clockwise on screen); the gap is the top-right opening.
const G_ARCS: Array[Array] = [
	[-0.05, 0.85, DS.GOOGLE_BLUE], [0.85, 2.35, DS.GOOGLE_GREEN],
	[2.35, 3.55, DS.GOOGLE_YELLOW], [3.55, 5.45, DS.GOOGLE_RED],
]
const G_STROKE_RATIO := 0.36
const LEAF_PAIRS := 3
const LEAF_SEGMENTS := 8
## Leaf half-width as a share of its length.
const LEAF_WIDTH := 0.22

@export var icon: Icon = Icon.LEAF
@export var tint: Color = DS.UI_SURFACE


func _init(p_icon: Icon = Icon.LEAF, p_size: float = DS.S8) -> void:
	icon = p_icon
	custom_minimum_size = Vector2.ONE * p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	match icon:
		Icon.GLOBE:
			_draw_globe(c, r)
		_:
			_draw_leaf(c, r)


static func draw_google_g(ci: CanvasItem, center: Vector2, radius: float) -> void:
	var width := radius * G_STROKE_RATIO
	var ring := radius - width * 0.5
	for arc: Array in G_ARCS:
		ci.draw_arc(center, ring, float(arc[0]), float(arc[1]), ARC_POINTS, arc[2] as Color, width, true)
	var bar := Rect2(center + Vector2(0.0, -width * 0.5), Vector2(radius, width))
	ci.draw_rect(bar, DS.GOOGLE_BLUE)


## A sprig: a gently leaning stem with alternating almond leaves, grass greens, sunlit tip leaf.
func _draw_leaf(c: Vector2, r: float) -> void:
	var base := c + Vector2(-r * 0.2, r * 0.95)
	var tip := c + Vector2(r * 0.15, -r * 0.7)
	draw_line(base, tip, DS.GRASS_SHADE, maxf(r * 0.07, 2.0), true)
	var stem_angle := (tip - base).angle()
	for i: int in LEAF_PAIRS:
		var at := base.lerp(tip, (i + 1.0) / (LEAF_PAIRS + 1.5))
		var length := r * (0.72 - 0.1 * i)
		_leaf(at, length, stem_angle - 0.95, DS.GRASS_MID)
		_leaf(at, length, stem_angle + 0.95, DS.GRASS_SHADE.lerp(DS.GRASS_MID, 0.5))
	_leaf(tip + (tip - base).normalized() * -r * 0.1, r * 0.55, stem_angle, DS.GRASS_SUN.lerp(DS.GRASS_MID, 0.4))


## Almond leaf from `at` along `angle`: two gentle arcs meeting at the point.
func _leaf(at: Vector2, length: float, angle: float, color: Color) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var pts := PackedVector2Array()
	for i: int in LEAF_SEGMENTS + 1:
		var t := float(i) / LEAF_SEGMENTS
		pts.append(at + dir * length * t + side * sin(t * PI) * length * LEAF_WIDTH)
	for i: int in range(LEAF_SEGMENTS - 1, 0, -1):
		var t := float(i) / LEAF_SEGMENTS
		pts.append(at + dir * length * t - side * sin(t * PI) * length * LEAF_WIDTH)
	draw_colored_polygon(pts, color)


func _draw_globe(c: Vector2, r: float) -> void:
	var w := maxf(r * 0.14, 1.5)
	draw_arc(c, r - w, 0.0, TAU, ARC_POINTS, tint, w, true)
	draw_line(c + Vector2(-r + w, 0.0), c + Vector2(r - w, 0.0), tint, w, true)
	var meridian := PackedVector2Array()
	for i: int in ARC_POINTS + 1:
		var a := TAU * i / ARC_POINTS
		meridian.append(c + Vector2(cos(a) * r * 0.42, sin(a) * (r - w)))
	draw_polyline(meridian, tint, w, true)
