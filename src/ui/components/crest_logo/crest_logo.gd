class_name CrestLogo
extends Control
## Game crest (design.md DS-CMP-15, logo concept C): a deep-teal shield with a teal inner shield,
## a wooden bat (-40°) crossed with a stone shaft (+40°), and a round bomb over the cross with a
## campfire spark on its fuse. Drawn in code from DS tokens only, so it scales to any size (the
## 1024 px brand PNG is rendered from it by scripts/export_crest.gd). States: idle (still) and
## animated (the spark flickers on the base motion token).

enum State { IDLE, ANIMATED }

const DEFAULT_SIZE := DS.S8 * 2.0
const INNER_SCALE := 0.8
const SHIELD_TOP := -0.88
const SHIELD_HALF_WIDTH := 0.78
const SHIELD_SHOULDER := -0.05
const SHIELD_TIP := 0.95
const CURVE_SEGMENTS := 12
const BAT_ANGLE := deg_to_rad(-40.0)
const SHAFT_ANGLE := deg_to_rad(40.0)
const BOMB_CENTER := Vector2(0.0, 0.32)
const BOMB_RADIUS := 0.3
const FUSE: Array[Vector2] = [Vector2(0.03, 0.02), Vector2(0.13, -0.12), Vector2(0.24, -0.15)]
const SPARK_POINTS := 5
const SPARK_RADIUS := 0.12
const SPARK_LOW := 0.8
const SPARK_HIGH := 1.2

var spark_scale: float = 1.0:
	set(value):
		spark_scale = value
		queue_redraw()

var _state: int = State.IDLE
var _flicker: Tween


func _init(p_size: float = DEFAULT_SIZE) -> void:
	custom_minimum_size = Vector2.ONE * p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(s: int) -> void:
	_state = s
	if _flicker != null and _flicker.is_valid():
		_flicker.kill()
	spark_scale = 1.0
	if s == State.ANIMATED and is_inside_tree():
		spark_scale = SPARK_LOW
		_flicker = UiMotion.pulse(self, "spark_scale", SPARK_LOW, SPARK_HIGH, UiMotion.Token.BASE)


func state() -> int:
	return _state


func set_preview() -> void:
	set_state.call_deferred(State.ANIMATED)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * r)
	draw_colored_polygon(shield_points(1.0), DS.CANOPY_DEEP)
	draw_colored_polygon(shield_points(INNER_SCALE), DS.CANOPY)
	_draw_rotated(size * 0.5, r, SHAFT_ANGLE, _draw_shaft)
	_draw_rotated(size * 0.5, r, BAT_ANGLE, _draw_bat)
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * r)
	_draw_bomb()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Shield outline in unit space (flat top, straight shoulders, curved sides to a bottom point).
static func shield_points(scale: float) -> PackedVector2Array:
	var w := SHIELD_HALF_WIDTH
	var pts := PackedVector2Array([Vector2(-w, SHIELD_TOP), Vector2(w, SHIELD_TOP), Vector2(w, SHIELD_SHOULDER)])
	var tip := Vector2(0.0, SHIELD_TIP)
	for i: int in range(1, CURVE_SEGMENTS + 1):
		pts.append(_quad(Vector2(w, SHIELD_SHOULDER), Vector2(w, 0.6), tip, float(i) / CURVE_SEGMENTS))
	for i: int in range(CURVE_SEGMENTS - 1, -1, -1):
		pts.append(_quad(Vector2(-w, SHIELD_SHOULDER), Vector2(-w, 0.6), tip, float(i) / CURVE_SEGMENTS))
	for i: int in pts.size():
		pts[i] *= scale
	return pts


static func star_points(center: Vector2, radius: float, points: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in points * 2:
		var a := -PI * 0.5 + PI * i / points
		out.append(center + Vector2.from_angle(a) * (radius if i % 2 == 0 else radius * 0.45))
	return out


static func _quad(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _draw_rotated(center: Vector2, r: float, angle: float, painter: Callable) -> void:
	draw_set_transform(center, angle, Vector2.ONE * r)
	painter.call()


## Stone shaft: a plain rod with round caps.
func _draw_shaft() -> void:
	draw_line(Vector2(0.0, -0.74), Vector2(0.0, 0.64), DS.STONE_SHADE, 0.09)
	draw_circle(Vector2(0.0, -0.74), 0.045, DS.STONE_SHADE)
	draw_circle(Vector2(0.0, 0.64), 0.045, DS.STONE_SHADE)


## Wooden bat: rounded dirt barrel tapering into a bark handle with a knob.
func _draw_bat() -> void:
	draw_circle(Vector2(0.0, -0.7), 0.1, DS.DIRT)
	draw_colored_polygon(PackedVector2Array([Vector2(-0.1, -0.7), Vector2(0.1, -0.7), Vector2(0.045, 0.05),
		Vector2(-0.045, 0.05)]), DS.DIRT)
	draw_line(Vector2(0.0, 0.03), Vector2(0.0, 0.62), DS.BARK, 0.07)
	draw_circle(Vector2(0.0, 0.66), 0.07, DS.BARK)


func _draw_bomb() -> void:
	draw_rect(Rect2(BOMB_CENTER + Vector2(-0.06, -BOMB_RADIUS - 0.05), Vector2(0.12, 0.08)), DS.CANOPY_DEEP)
	draw_circle(BOMB_CENTER, BOMB_RADIUS, DS.CANOPY_DEEP)
	draw_circle(BOMB_CENTER + Vector2(-0.1, -0.1), 0.075, DS.UI_TEXT_SOFT)
	draw_polyline(PackedVector2Array(FUSE), DS.DIRT, 0.045)
	var tip: Vector2 = FUSE[FUSE.size() - 1]
	draw_colored_polygon(star_points(tip, SPARK_RADIUS * spark_scale, SPARK_POINTS), DS.FIRE)
