class_name BotNav
extends RefCounted
## A bot's ground sense (split out of BotController, unchanged logic): the view's arena, built
## once per id from ArenaCatalog with its floors synced from the view, and walking that never
## steps where bot_ground_lookahead ahead has no floor. Shared by BotController and BotProbe.

var _config: GameConfig
var _arena: ArenaData = null


func _init(p_config: GameConfig) -> void:
	_config = p_config


## The view's arena (built once per id from ArenaCatalog), with its floors set from the view.
func arena_for(view: Dictionary) -> ArenaData:
	var id := String(view.get("arena", ArenaCatalog.DEFAULT_ID))
	if _arena == null or _arena.id != id:
		_arena = ArenaCatalog.build(id, _config)
		if _arena == null:
			_arena = ArenaCatalog.default(_config)
	_arena.sync(_config)
	var floors: Array = view.get("arena_floors", [])
	if floors.size() == _arena.floor_active.size():
		_arena.floor_active.assign(floors)
	return _arena


## Moves along dir, or slides along its larger then smaller axis, whichever first keeps floor
## within bot_ground_lookahead ahead; stands still when none does.
func walk(dir: Vector2, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	var ax := Vector2(signf(dir.x), 0.0)
	var az := Vector2(0.0, signf(dir.y))
	var options: Array[Vector2] = [dir, ax, az]
	if absf(dir.y) > absf(dir.x):
		options = [dir, az, ax]
	for d: Vector2 in options:
		var ahead := my_pos + Vector3(d.x, 0.0, d.y) * _config.bot_ground_lookahead
		if d != Vector2.ZERO and ArenaFloor.over_floor(arena, ahead):
			return InputFrame.make(d.x, d.y)
	return InputFrame.neutral()
