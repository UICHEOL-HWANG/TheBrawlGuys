class_name ArenaData
extends RefCounted
## One arena for the pure sim (PRD §6.1, PRD-ARCH-03): walkable floor shapes, ring-out rules,
## spawn points, the item drop area and the gimmicks, plus theme_id for the render layer.
## A World owns its own copy: floor_active and the gimmicks carry per-match state that goes into
## snapshots (to_data / load_data). Geometry is fixed data; follow_config arenas (the classic
## circle) re-read arena_radius from GameConfig so the debug slider keeps working.

const SPAWN_RADIUS_RATIO := 0.5

var id: String = ""
var theme_id: String = ""
var floors: Array[ArenaShape] = []
## Parallel to floors; false while a gimmick has removed the floor (broken bridge segment).
var floor_active: Array[bool] = []
## Below a zone's center.y and inside it = ring-out, reported with the zone's tag.
var ringout_zones: Array[ArenaShape] = []
## Horizontal ring-out distance from the world origin (floor bound + GameConfig.blast_margin).
var blast_radius: float = 0.0
var kill_y: float = 0.0
## Fixed spawn points; empty means a ring of spawn_radius around the origin (Phase 1 layout).
var spawn_points: Array[Vector3] = []
var spawn_radius: float = 0.0
## Where item boxes land (ItemField draws a point inside it).
var item_area: ArenaShape = null
var gimmicks: Array[Gimmick] = []
var follow_config: bool = false
## Farthest floor reach from the origin, kept up to date by add_floor and sync.
var _floor_bound: float = 0.0


func add_floor(shape: ArenaShape) -> int:
	floors.append(shape)
	floor_active.append(true)
	_floor_bound = maxf(_floor_bound, shape.bound_radius())
	return floors.size() - 1


func add_gimmick(g: Gimmick) -> void:
	g.id = gimmicks.size()
	gimmicks.append(g)


## Reads the config-driven parts: blast margin and kill_y always, the floor radius for
## follow_config arenas. Called at construction and at the start of every tick.
func sync(config: GameConfig) -> void:
	if follow_config and not floors.is_empty():
		floors[0].radius = config.arena_radius
		if item_area != null:
			item_area.radius = config.arena_radius
		_floor_bound = config.arena_radius
		spawn_radius = config.arena_radius * SPAWN_RADIUS_RATIO
	blast_radius = _floor_bound + config.blast_margin
	kill_y = config.kill_y


## Radius used by views and bots that think in circles (the whole floor for non-circle arenas).
func view_radius() -> float:
	return _floor_bound


func spawn_point(index: int, count: int) -> Vector3:
	if not spawn_points.is_empty():
		return spawn_points[index % spawn_points.size()]
	var angle := PI + TAU * float(index) / float(maxi(count, 1))
	var r := spawn_radius
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


func copy() -> ArenaData:
	var a := ArenaData.new()
	a.id = id
	a.theme_id = theme_id
	for s: ArenaShape in floors:
		a.floors.append(s.copy())
	a.floor_active = floor_active.duplicate()
	for z: ArenaShape in ringout_zones:
		a.ringout_zones.append(z.copy())
	a.blast_radius = blast_radius
	a.kill_y = kill_y
	a.spawn_points = spawn_points.duplicate()
	a.spawn_radius = spawn_radius
	a.item_area = item_area.copy() if item_area != null else null
	for g: Gimmick in gimmicks:
		a.gimmicks.append(g.copy())
	a.follow_config = follow_config
	a._floor_bound = _floor_bound
	return a


## Per-match gimmick setup (schedules read from the config); World calls it once.
func start(config: GameConfig) -> void:
	sync(config)
	for g: Gimmick in gimmicks:
		g.start(config)


func gimmick_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Gimmick in gimmicks:
		out.append(g.to_view())
	return out


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for g: Gimmick in gimmicks:
		list.append(g.to_data())
	return {"id": id, "floor_active": floor_active.duplicate(), "gimmicks": list}


## Loads per-match state saved by to_data into this arena (same id). Returns false and leaves
## the arena untouched when the data does not fit.
func load_data(d: Dictionary) -> bool:
	if typeof(d.get("id")) != TYPE_STRING or d["id"] != id:
		return false
	if typeof(d.get("floor_active")) != TYPE_ARRAY or typeof(d.get("gimmicks")) != TYPE_ARRAY:
		return false
	var active: Array = d["floor_active"]
	var states: Array = d["gimmicks"]
	if active.size() != floors.size() or states.size() != gimmicks.size():
		return false
	for v: Variant in active:
		if typeof(v) != TYPE_BOOL:
			return false
	var loaded: Array[Gimmick] = []
	for i: int in gimmicks.size():
		var g := gimmicks[i].copy()
		if not (states[i] is Dictionary) or not g.load_data(states[i]):
			return false
		loaded.append(g)
	floor_active.assign(active)
	gimmicks = loaded
	return true
