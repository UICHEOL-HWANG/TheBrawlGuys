class_name BotController
extends RefCounted
## Bot step 2 (PRD §6.4): step 1 (approach, attack in range, retreat from the edge, recover) plus
## guarding every other attack that starts in range (BotDefense, so it can still be hit), racing for nearby
## items (also while they are still falling), swinging bats, throwing rocks and bombs at range, mashing the light combo, grabbing a
## guarding foe and throwing held fighters toward the nearest edge. Reads only state_view() values
## and produces InputFrames — never touches the sim. Deterministic (no randomness).
## Ground sense (Phase 4): the arena comes from the view's "arena" id (ArenaCatalog) and its
## "arena_floors"; "edge" means less than extent * (1 - bot_edge_ratio) inside a floor, and the
## bot never walks where bot_ground_lookahead ahead has no floor.
## Styles (Phase 5, BotStyleSense): swing range scales with the style's reach, ranged bots keep
## their distance and shoot, and a full gauge fires the special (heavy+guard) once a foe is in reach.
## Defense (combat-depth A, BotDefense): guards after a reaction delay, rolls on the other turns.
## Knockdowns (combat-depth C, BotGetup): varied getup options, sometimes a tech.

## Pick up when the item is this deep inside the pickup radius (a margin against rounding).
const PICKUP_REACH_RATIO := 0.8

var _self_id: int
var _config: GameConfig
var _arena: ArenaData = null
var _cooldown: int = 0
var _combo_left: int = 0
var _defense: BotDefense
var _getup: BotGetup


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config
	_defense = BotDefense.new(p_self_id, p_config)
	_getup = BotGetup.new(p_self_id, p_config)


## Light presses after the first swing so hits 2 and 3 land inside the combo buffer.
static func combo_mash_ticks(config: GameConfig) -> int:
	return 2 * (config.light_startup_ticks + config.light_active_ticks + config.light_recovery_ticks)


## Swing range of bot `id`: staggered by id so mirrored bots never start the same trade forever.
static func attack_range(id: int, config: GameConfig) -> float:
	return config.bot_attack_range - config.bot_attack_range_spread * float(id % 4)


func sample(view: Dictionary) -> InputFrame:
	var sent := _sample(view)
	_defense.note(sent)
	return sent


func _sample(view: Dictionary) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
	var me := BotViewQuery.find(view, _self_id)
	if me.is_empty() or int(me["state"]) == Fighter.State.KO:
		return InputFrame.neutral()
	var arena := _arena_for(view)
	var my_pos: Vector3 = me["pos"]
	var foe := BotViewQuery.nearest_foe(view, _self_id, my_pos)
	var safe := BotViewQuery.flat(my_pos, ArenaFloor.safe_point(arena, my_pos, _config.bot_edge_ratio)).normalized()
	# Decided every tick (even during recovery/edge/holding) so the every-other toggle never goes stale.
	var tick := int(view.get("tick", 0))
	var defense := _defense.decide(me, foe, safe, _closing(me, foe), tick)
	var getup := _getup.decide(me, foe, tick, arena)
	if not bool(me["on_ground"]) and my_pos.y < 0.0 and not ArenaFloor.over_floor(arena, my_pos):
		return InputFrame.make(safe.x, safe.y, int(me["jumps_left"]) > 0)
	if getup != null:
		return getup
	if int(me["state"]) == Fighter.State.HOLDING:
		var out := ArenaFloor.outward(arena, my_pos)
		return InputFrame.make(out.x, out.y, false, false, false, false, true)
	var rolling := defense != null and (defense.move_x != 0.0 or defense.move_z != 0.0)
	if safe != Vector2.ZERO and not rolling:
		return InputFrame.make(safe.x, safe.y)
	if defense != null:
		return defense
	if _combo_left > 0:
		_combo_left -= 1
		return InputFrame.make(0, 0, false, true)
	return _act(view, me, foe, arena)


## Items first (throwables, then pickups the foe cannot also reach), otherwise fight the nearest foe.
func _act(view: Dictionary, me: Dictionary, foe: Dictionary, arena: ArenaData) -> InputFrame:
	var my_pos: Vector3 = me["pos"]
	var item_kind := int(me.get("item_kind", Fighter.NONE))
	if item_kind == Item.Kind.BOMB or item_kind == Item.Kind.ROCK:
		return _use_throwable(foe, my_pos, arena)
	if item_kind == Fighter.NONE:
		var it := BotViewQuery.nearest_item(view, my_pos, arena, _config)
		var reach := _config.item_pickup_radius * PICKUP_REACH_RATIO
		if not it.is_empty() and not BotViewQuery.contested(it, foe, reach):
			var to_item := BotViewQuery.flat(my_pos, it["pos"])
			if to_item.length() <= reach and bool(me["on_ground"]):
				if int(it["state"]) == Item.State.FALLING:
					return InputFrame.neutral()  # wait under it; a grab press now would start a grab attack
				return InputFrame.make(0, 0, false, false, false, false, true)
			return _walk(to_item.normalized(), my_pos, arena)
	return _fight(me, foe, item_kind, arena)


## A melee bot with no combo running and no special to fire, the foe not yet within its own
## swing range: the moment an early guard turn may raise its guard as the foe closes (BotDefense).
func _closing(me: Dictionary, foe: Dictionary) -> bool:
	if foe.is_empty() or _combo_left > 0 or BotStyleSense.is_ranged(me) or BotStyleSense.special_ready(me, foe, _config):
		return false
	return BotViewQuery.flat(me["pos"], foe["pos"]).length() > BotStyleSense.melee_range(me, _self_id, _config)


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


## Moves along dir, or slides along its larger then smaller axis, whichever first keeps floor
## within bot_ground_lookahead ahead; stands still when none does.
func _walk(dir: Vector2, my_pos: Vector3, arena: ArenaData) -> InputFrame:
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


func _use_throwable(foe: Dictionary, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := BotViewQuery.flat(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_throw_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	return _walk(dir, my_pos, arena)


func _fight(me: Dictionary, foe: Dictionary, item_kind: int, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var my_pos: Vector3 = me["pos"]
	var delta := BotViewQuery.flat(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if BotStyleSense.special_ready(me, foe, _config):
		return InputFrame.make(dir.x, dir.y, false, false, true, true)
	var reach := _config.grab_forward + _config.grab_half_width + _config.fighter_radius
	if int(foe["state"]) == Fighter.State.GUARD and delta.length() <= reach:
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	if item_kind == Fighter.NONE and BotStyleSense.is_ranged(me):
		return _shoot(me, delta, my_pos, arena)
	if delta.length() <= BotStyleSense.melee_range(me, _self_id, _config) and _cooldown == 0:
		if BotStyleSense.has_special(me) and not BotStyleSense.aimed(me, delta):
			return InputFrame.make(dir.x, dir.y)  # an attack starts along the facing: turn first
		_cooldown = _config.bot_attack_cooldown_ticks
		if item_kind != Item.Kind.BAT:
			_combo_left = combo_mash_ticks(_config)
		return InputFrame.make(dir.x, dir.y, false, true)
	return _walk(dir, my_pos, arena)


## Ranged style: back off inside the keep distance (unless cornered), close in from afar, turn to
## face the foe, then fire a bolt volley.
func _shoot(me: Dictionary, delta: Vector2, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var plan := BotStyleSense.ranged_plan(me, delta, _config)
	if plan == BotStyleSense.Ranged.RETREAT:
		var away := _walk(-dir, my_pos, arena)
		if away.move_x != 0.0 or away.move_z != 0.0:
			return away
		plan = BotStyleSense.Ranged.FIRE if BotStyleSense.aimed(me, delta) else BotStyleSense.Ranged.TURN
	if plan == BotStyleSense.Ranged.APPROACH:
		return _walk(dir, my_pos, arena)
	if plan == BotStyleSense.Ranged.TURN:
		return InputFrame.make(dir.x, dir.y)
	if _cooldown > 0:
		return InputFrame.neutral()
	_cooldown = _config.bot_attack_cooldown_ticks
	_combo_left = combo_mash_ticks(_config)
	return InputFrame.make(0, 0, false, true)
