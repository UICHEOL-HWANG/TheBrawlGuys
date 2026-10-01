class_name PlayerStyle
extends RefCounted
## Player identity (design.md DS-VIS-03): color + shape + label — never color alone.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }

const COLORS := [DS.P1, DS.P2, DS.P3, DS.P4]
const TEAM_COLORS := [DS.TEAM_1, DS.TEAM_2]
const SHAPES := [Shape.CIRCLE, Shape.TRIANGLE, Shape.SQUARE, Shape.DIAMOND]
const CIRCLE_SEGMENTS := 24


static func color(index: int) -> Color:
	return COLORS[posmod(index, COLORS.size())]


static func shape(index: int) -> int:
	return SHAPES[posmod(index, SHAPES.size())]


static func label(index: int) -> String:
	return "P%d" % (index + 1)


## Team 2v2 (combat-depth D): team 0 -> TEAM_1, team 1 -> TEAM_2.
static func team_color(team: int) -> Color:
	return TEAM_COLORS[posmod(team, TEAM_COLORS.size())]


static func team_label(team: int) -> String:
	return "팀 %d" % (team + 1)


static func polygon(shape_id: int, radius: float, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var count := CIRCLE_SEGMENTS
	var start := 0.0
	match shape_id:
		Shape.TRIANGLE:
			count = 3
			start = -PI / 2.0
		Shape.SQUARE:
			count = 4
			start = PI / 4.0
		Shape.DIAMOND:
			count = 4
			start = -PI / 2.0
	var pts := PackedVector2Array()
	for i: int in count:
		var a := start + TAU * float(i) / float(count)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
