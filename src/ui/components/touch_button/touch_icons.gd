class_name TouchIcons
extends RefCounted
## Touch button icons (design.md DS-CMP-04), drawn from round primitives in the form language
## of design.md §3: no sharp spikes. size is the icon's half extent in pixels.

enum Icon { ATTACK, JUMP, GUARD, GRAB }

## Line width as a fraction of the icon size.
const STROKE_RATIO := 0.16
const SEGMENTS := 24


static func draw(canvas: CanvasItem, icon: int, center: Vector2, size: float, color: Color) -> void:
	var w := maxf(size * STROKE_RATIO, 2.0)
	match icon:
		Icon.ATTACK:
			# a round fist: palm circle with three knuckles on top
			canvas.draw_circle(center + Vector2(0, size * 0.15), size * 0.55, color)
			for i: int in 3:
				canvas.draw_circle(center + Vector2((i - 1) * size * 0.42, -size * 0.45), size * 0.24, color)
		Icon.JUMP:
			# two soft upward chevrons
			for k: int in 2:
				var y := center.y + size * (0.35 - k * 0.55)
				canvas.draw_polyline(PackedVector2Array([
					Vector2(center.x - size * 0.6, y + size * 0.3), Vector2(center.x, y - size * 0.25),
					Vector2(center.x + size * 0.6, y + size * 0.3)]), color, w, true)
		Icon.GUARD:
			# rounded shield
			var pts := PackedVector2Array()
			for i: int in SEGMENTS + 1:
				var a := PI * float(i) / SEGMENTS
				pts.append(center + Vector2(cos(a) * size * 0.7, sin(a) * size * 0.9 - size * 0.1))
			pts.append(center + Vector2(-size * 0.7, -size * 0.6))
			pts.append(center + Vector2(size * 0.7, -size * 0.6))
			canvas.draw_colored_polygon(pts, color)
		Icon.GRAB:
			# an open cupped hand: a thick arc with a dot inside
			canvas.draw_arc(center, size * 0.6, deg_to_rad(-60.0), deg_to_rad(240.0), SEGMENTS, color, w * 1.5, true)
			canvas.draw_circle(center, size * 0.22, color)
