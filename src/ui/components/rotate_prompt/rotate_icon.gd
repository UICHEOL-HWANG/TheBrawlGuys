class_name RotateIcon
extends Control
## "Turn the phone sideways" mark for the rotate prompt (design.md DS-LAY-04, DS-TOK-06 icon
## style): a rounded phone outline in ui_text that tips from portrait to landscape, and a curved
## fire arrow showing the turn. Drawn in code from DS tokens; `tilt` (radians) is animated.

const STROKE_RATIO := 6.0 / 64.0
const ARC_POINTS := 24
## Phone body in icon units (icon = 1.0 across): portrait 0.36 x 0.62.
const BODY := Vector2(0.36, 0.62)
const ARROW_RADIUS := 0.44
const ARROW_FROM := -PI * 0.95
const ARROW_TO := -PI * 0.55
const TURN := PI * 0.5

## 0 = portrait, TURN = landscape.
var tilt: float = 0.0:
	set(v):
		tilt = v
		queue_redraw()


func _init(p_size: float = DS.ROTATE_ICON_SIZE) -> void:
	custom_minimum_size = Vector2.ONE * p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Tips portrait <-> landscape on motion_slow steps while the prompt is shown (UiMotion.pulse).
func play() -> Tween:
	return UiMotion.pulse(self, "tilt", 0.0, TURN, UiMotion.Token.SLOW)


func _draw() -> void:
	var unit := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(unit * STROKE_RATIO, 2.0)
	_draw_arrow(c, unit, w)
	draw_set_transform(c, tilt)
	var body := Rect2(-BODY * unit * 0.5, BODY * unit)
	var box := StyleBoxFlat.new()
	box.bg_color = DS.UI_SURFACE
	box.border_color = DS.UI_TEXT
	box.set_border_width_all(int(w))
	box.set_corner_radius_all(int(unit * 0.07))
	draw_style_box(box, body)
	draw_circle(Vector2(0.0, body.end.y - w * 1.6), w * 0.55, DS.UI_TEXT)
	draw_set_transform(Vector2.ZERO)


func _draw_arrow(c: Vector2, unit: float, w: float) -> void:
	var r := unit * ARROW_RADIUS
	draw_arc(c, r, ARROW_FROM, ARROW_TO, ARC_POINTS, DS.FIRE, w, true)
	var tip := c + Vector2(cos(ARROW_TO), sin(ARROW_TO)) * r
	var along := Vector2(-sin(ARROW_TO), cos(ARROW_TO))  # tangent, direction of travel
	var side := Vector2(cos(ARROW_TO), sin(ARROW_TO))
	var head := PackedVector2Array([tip + along * w * 2.2, tip - along * w * 0.6 + side * w * 1.8,
			tip - along * w * 0.6 - side * w * 1.8])
	draw_colored_polygon(head, DS.FIRE)
