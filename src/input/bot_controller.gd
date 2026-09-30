class_name BotController
extends RefCounted
## Bot step 2 (PRD §6.4): step 1 (approach, attack in range, retreat from the edge, recover) plus
## guarding every other attack that starts in range (so it can still be hit), racing for nearby
## items (also while they are still falling), swinging bats, throwing rocks and bombs at range, mashing the light combo, grabbing a
## guarding foe and throwing held fighters toward the nearest edge. Reads only state_view() values
## and produces InputFrames — never touches the sim. Deterministic (no randomness).
## Ground sense (Phase 4): the arena comes from the view's "arena" id (ArenaCatalog) and its
## "arena_floors"; "edge" means less than extent * (1 - bot_edge_ratio) inside a floor, and the
## bot never walks where bot_ground_lookahead ahead has no floor.

## Pick up when the item is this deep inside the pickup radius (a margin against rounding).
const PICKUP_REACH_RATIO := 0.8

var _self_id: int
var _config: GameConfig
var _arena: ArenaData = null
var _cooldown: int = 0
var _combo_left: int = 0
var _guard_left: int = 0
var _guard_next_threat: bool = true
var _foe_was_threat: bool = false


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


## Light presses after the first swing so hits 2 and 3 land inside the combo buffer.
static func combo_mash_ticks(config: GameConfig) -> int:
	return 2 * (config.light_startup_ticks + config.light_active_ticks + config.light_recovery_ticks)


func sample(view: Dictionary) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
	var me := _find(view, _self_id)
	if me.is_empty() or int(me["state"]) == Fighter.State.KO:
		return InputFrame.neutral()
	var arena := _arena_for(view)
	var my_pos: Vector3 = me["pos"]
	# Tracked every tick (even during recovery/edge/holding) so the every-other-threat toggle
	# never goes stale.
	var foe := _nearest_foe(view, my_pos)
	var guarding := _update_guard(foe, my_pos)
	var safe := _flat_delta(my_pos, ArenaFloor.safe_point(arena, my_pos, _config.bot_edge_ratio)).normalized()
	if not bool(me["on_ground"]) and my_pos.y < 0.0 and not ArenaFloor.over_floor(arena, my_pos):
		return InputFrame.make(safe.x, safe.y, int(me["jumps_left"]) > 0)
	if int(me["state"]) == Fighter.State.HOLDING:
		var out := ArenaFloor.outward(arena, my_pos)
		return InputFrame.make(out.x, out.y, false, false, false, false, true)
	if safe != Vector2.ZERO:
		return InputFrame.make(safe.x, safe.y)
	if guarding:
		return InputFrame.make(0, 0, false, false, false, true)
	if _combo_left > 0:
		_combo_left -= 1
		return InputFrame.make(0, 0, false, true)
	return _act(view, me, foe, arena)


## Items first (throwables, then pickups), otherwise fight the nearest foe.
func _act(view: Dictionary, me: Dictionary, foe: Dictionary, arena: ArenaData) -> InputFrame:
	var my_pos: Vector3 = me["pos"]
	var item_kind := int(me.get("item_kind", Fighter.NONE))
	if item_kind == Item.Kind.BOMB or item_kind == Item.Kind.ROCK:
		return _use_throwable(foe, my_pos, arena)
	if item_kind == Fighter.NONE:
		var it := _nearest_item(view, my_pos, arena)
		if not it.is_empty():
			var to_item := _flat_delta(my_pos, it["pos"])
			if to_item.length() <= _config.item_pickup_radius * PICKUP_REACH_RATIO and bool(me["on_ground"]):
				if int(it["state"]) == Item.State.FALLING:
					return InputFrame.neutral()  # wait under it; a grab press now would start a grab attack
				return InputFrame.make(0, 0, false, false, false, false, true)
			return _walk(to_item.normalized(), my_pos, arena)
	return _fight(foe, my_pos, item_kind, arena)


## The view's arena (built once per id from ArenaCatalog), with its floors set from the view.
func _arena_for(view: Dictionary) -> ArenaData:
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


## Moves along dir unless that walks off the floor within bot_ground_lookahead (then stands).
func _walk(dir: Vector2, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	var ahead := my_pos + Vector3(dir.x, 0.0, dir.y) * _config.bot_ground_lookahead
	if not ArenaFloor.over_floor(arena, ahead):
		return InputFrame.neutral()
	return InputFrame.make(dir.x, dir.y)


## Starts a guard on every other new threat and keeps it for bot_guard_ticks.
func _update_guard(foe: Dictionary, my_pos: Vector3) -> bool:
	var threat := not foe.is_empty() and _flat_delta(my_pos, foe["pos"]).length() <= _config.bot_guard_range \
			and (int(foe["state"]) == Fighter.State.ATTACK or int(foe["state"]) == Fighter.State.CHARGE)
	if threat and not _foe_was_threat:
		if _guard_next_threat:
			_guard_left = _config.bot_guard_ticks
		_guard_next_threat = not _guard_next_threat
	_foe_was_threat = threat
	if _guard_left > 0:
		_guard_left -= 1
		return true
	return false


func _use_throwable(foe: Dictionary, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_throw_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	return _walk(dir, my_pos, arena)


func _fight(foe: Dictionary, my_pos: Vector3, item_kind: int, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var reach := _config.grab_forward + _config.grab_half_width + _config.fighter_radius
	if int(foe["state"]) == Fighter.State.GUARD and delta.length() <= reach:
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	if delta.length() <= _config.bot_attack_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		if item_kind != Item.Kind.BAT:
			_combo_left = combo_mash_ticks(_config)
		return InputFrame.make(dir.x, dir.y, false, true)
	return _walk(dir, my_pos, arena)


static func _find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func _flat_delta(from: Vector3, to: Vector3) -> Vector2:
	return Vector2(to.x - from.x, to.z - from.z)


func _nearest_foe(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == _self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var d := _flat_delta(my_pos, f["pos"]).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best


## Nearest lit-free item on the ground, or still falling (it lands straight below at pos.x, pos.z)
## as long as that landing spot is safe ground (not near an edge or over a gap).
func _nearest_item(view: Dictionary, my_pos: Vector3, arena: ArenaData) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := _config.bot_item_seek_range
	for it: Dictionary in view.get("items", []):
		var state := int(it["state"])
		if state != Item.State.GROUND and state != Item.State.FALLING:
			continue
		if int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var landing: Vector3 = it["pos"]
		if state == Item.State.FALLING and not _is_safe(arena, Vector3(landing.x, 0.0, landing.z)):
			continue
		var d := _flat_delta(my_pos, it["pos"]).length()
		if d <= best_dist:
			best_dist = d
			best = it
	return best


func _is_safe(arena: ArenaData, pos: Vector3) -> bool:
	return ArenaFloor.over_floor(arena, pos) and ArenaFloor.safe_point(arena, pos, _config.bot_edge_ratio) == pos
