class_name ArenaView
extends Node3D
## Draws the arena a match is played on (PRD §6.1, design.md DS-VIS-04, DS-THM-02) from the sim's
## own ArenaData for an ArenaCatalog id: the walkable floors (FloorMesh), water under the ring-out
## zones (WaterView) and one view per gimmick (GimmickViews) in the arena's theme colors. sync()
## follows the per-tick arena state (floors still standing, gimmick states); on_events() hands
## this frame's sim events (bounces) to the gimmick views. A follow_config arena (the classic
## circle) rebuilds when arena_radius changes so the debug slider keeps working.

const WATER_SEED := 7

var _config: GameConfig
var _id: String = ArenaCatalog.DEFAULT_ID
var _arena: ArenaData
var _theme: ArenaTheme
## One node per arena floor (null where a gimmick view draws the floor itself).
var _floors: Array[Node3D] = []
var _gimmicks: Dictionary = {}
var _built_radius: float = -1.0


func setup(config: GameConfig, arena_id: String = ArenaCatalog.DEFAULT_ID) -> void:
	_config = config
	_id = arena_id
	_config.changed.connect(_on_config_changed)
	_rebuild()


func arena() -> ArenaData:
	return _arena


func theme() -> ArenaTheme:
	return _theme


func arena_id() -> String:
	return _arena.id


## Per-tick arena state from World.state_view(): arena_floors and gimmicks.
func sync(view: Dictionary, tick: int, delta: float) -> void:
	var active: Array = view.get("arena_floors", [])
	for i: int in mini(_floors.size(), active.size()):
		if _floors[i] != null:
			_floors[i].visible = bool(active[i])
	for g: Dictionary in view.get("gimmicks", []):
		var gv := gimmick_view(int(g["id"]))
		if gv != null:
			gv.sync(g, tick, delta)


func on_events(events: Array) -> void:
	for e: Dictionary in events:
		for gv: GimmickView in _gimmicks.values():
			gv.on_event(e)


## Strongest fog among the gimmick views (0 when the arena has no fog).
func fog_amount() -> float:
	var out := 0.0
	for gv: GimmickView in _gimmicks.values():
		out = maxf(out, gv.fog_amount())
	return out


func gimmick_view(id: int) -> GimmickView:
	return _gimmicks.get(id) as GimmickView


func gimmick_views() -> Array[GimmickView]:
	var out: Array[GimmickView] = []
	for gv: GimmickView in _gimmicks.values():
		out.append(gv)
	return out


## Floors this view draws itself (gimmick-owned floors are drawn by their views).
func drawn_floor_count() -> int:
	var n := 0
	for f: Node3D in _floors:
		if f != null:
			n += 1
	return n


func _on_config_changed() -> void:
	if _arena.follow_config and not is_equal_approx(_config.arena_radius, _built_radius):
		_rebuild()


func _rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_floors.clear()
	_gimmicks.clear()
	_arena = ArenaCatalog.build(_id, _config) if ArenaCatalog.ids().has(_id) else ArenaCatalog.default(_config)
	_theme = ArenaTheme.for_id(_arena.theme_id)
	_built_radius = _config.arena_radius
	var owned := _build_gimmicks()
	for i: int in _arena.floors.size():
		var node: Node3D = null
		if not owned.has(i):
			node = FloorMesh.build(_arena.floors[i].to_view(), _theme)
			add_child(node)
		_floors.append(node)
	var zones: Array[Dictionary] = []
	for z: ArenaShape in _arena.ringout_zones:
		zones.append(z.to_view())
	if not zones.is_empty():
		var water := WaterView.new()
		add_child(water)
		water.setup(zones, _theme, WATER_SEED)


## Builds the gimmick views; returns the floor indices they draw themselves.
func _build_gimmicks() -> Array[int]:
	var owned: Array[int] = []
	for g: Dictionary in _arena.gimmick_views():
		var gv := GimmickViews.create(String(g["kind"]))
		if gv == null:
			continue
		add_child(gv)
		gv.setup(g, _theme, _config)
		_gimmicks[int(g["id"])] = gv
		if gv.owned_floor() >= 0:
			owned.append(gv.owned_floor())
	return owned
