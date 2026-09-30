class_name BombModel
extends ItemModel
## Round bomb (design.md DS-VIS-05, Phase 4 T8): a berry body with a soft highlight, a metal cap
## and a curled fuse. Once lit, a fire spark creeps down the fuse toward the cap and blinks
## faster and faster until the explosion. Origin on the ground under the body.

const BODY_RADIUS := 0.3
const HIGHLIGHT_RADIUS := 0.07
const CAP_RADIUS := 0.09
const CAP_HEIGHT := 0.08
const FUSE_RADIUS := 0.022
## Fuse polyline from the cap (index 0) to the tip.
const FUSE_POINTS: Array[Vector3] = [Vector3(0, 0.66, 0), Vector3(0.03, 0.74, 0),
		Vector3(0.09, 0.8, 0), Vector3(0.17, 0.81, 0)]
const SPARK_RADIUS := 0.07
const SPARK_CORE_RATIO := 0.5
const BLINK_HZ_START := 4.0
const BLINK_HZ_END := 14.0
const DEFAULT_FUSE_TICKS := 120
## Held out at the side, fuse up, a little smaller. KayKit's handslot.r: -x is up and +z points
## away from the body in the idle pose (probed with a capture), so model +Y maps to slot -x and
## the body center sits just outside the hand.
const HOLD := Transform3D(Vector3(0, 0.8, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0.24, 0, 0.2))

## Ticks of a full fuse (SimTime.to_ticks(GameConfig.bomb_fuse_time)); ItemView sets it.
var fuse_total: int = DEFAULT_FUSE_TICKS
var _segments: Array[MeshInstance3D] = []
var _spark: Node3D


## Fraction of the fuse left: 1 while unlit, 0 at the explosion.
static func burn_left(fuse_ticks: int, total: int) -> float:
	if fuse_ticks < 0:
		return 1.0
	return clampf(float(fuse_ticks) / float(maxi(total, 1)), 0.0, 1.0)


static func blink_hz(fuse_ticks: int, total: int) -> float:
	return lerpf(BLINK_HZ_START, BLINK_HZ_END, 1.0 - burn_left(fuse_ticks, total))


static func spark_on(fuse_ticks: int, total: int, tick: int) -> bool:
	if fuse_ticks <= 0:
		return false
	var hz := blink_hz(fuse_ticks, total)
	return floori(float(tick) * hz * 2.0 / SimTime.TICK_RATE) % 2 == 0


## Point on the fuse at fraction t (0 = cap, 1 = tip).
static func fuse_point(t: float) -> Vector3:
	var span := float(FUSE_POINTS.size() - 1)
	var f := clampf(t, 0.0, 1.0) * span
	var i := mini(floori(f), FUSE_POINTS.size() - 2)
	return FUSE_POINTS[i].lerp(FUSE_POINTS[i + 1], f - i)


func show_state(view: Dictionary, tick: int) -> void:
	var fuse := int(view.get("fuse_ticks", Item.UNLIT))
	var left := burn_left(fuse, fuse_total)
	_spark.position = fuse_point(left)
	_spark.visible = spark_on(fuse, fuse_total, tick)
	var span := float(_segments.size())
	for i: int in _segments.size():
		_segments[i].visible = float(i) < left * span  # burnt segments are gone


func spark_visible() -> bool:
	return _spark.visible


func spark_height() -> float:
	return _spark.position.y


func hold_transform() -> Transform3D:
	return HOLD


func _build() -> void:
	_part(ItemParts.sphere(BODY_RADIUS), DS.BERRY, ItemParts.at(Vector3(0, BODY_RADIUS, 0)))
	_part(ItemParts.sphere(HIGHLIGHT_RADIUS), DS.PETAL_PINK,
			ItemParts.at(Vector3(-0.12, BODY_RADIUS + 0.16, 0.19), Vector3.ZERO, Vector3(1, 0.7, 1)))
	_part(ItemParts.cylinder(CAP_RADIUS, CAP_RADIUS * 1.15, CAP_HEIGHT), DS.STONE_SHADE,
			ItemParts.at(Vector3(0, BODY_RADIUS * 2.0 + CAP_HEIGHT * 0.2, 0)))
	for i: int in FUSE_POINTS.size() - 1:
		_segments.append(_fuse_segment(FUSE_POINTS[i], FUSE_POINTS[i + 1]))
	_spark = Node3D.new()
	add_child(_spark)
	_part(ItemParts.sphere(SPARK_RADIUS), DS.FIRE, Transform3D.IDENTITY, _spark)
	_part(ItemParts.sphere(SPARK_RADIUS * SPARK_CORE_RATIO), DS.GLOW,
			ItemParts.at(Vector3(0, 0, SPARK_RADIUS * 0.5)), _spark)
	_spark.position = FUSE_POINTS.back()
	_spark.visible = false


func _fuse_segment(a: Vector3, b: Vector3) -> MeshInstance3D:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.BACK).normalized()
	var frame := Basis(side, up, side.cross(up))
	var mesh := ItemParts.cylinder(FUSE_RADIUS, FUSE_RADIUS, d.length() + FUSE_RADIUS)
	return _part(mesh, DS.DIRT, Transform3D(frame, (a + b) * 0.5))
