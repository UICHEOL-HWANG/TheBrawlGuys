class_name BotController
extends RefCounted
## Bot (PRD §6.4): approach, attack in range, retreat from the edge, recover; guard every other
## threat (BotDefense), race for items, swing bats, throw rocks and bombs, mash the light combo,
## grab a guarding foe, throw held fighters toward the nearest edge. Reads only state_view()
## values and produces InputFrames — never touches the sim; any randomness is a deterministic hash.
## Ground sense (Phase 4, BotNav): never walks where bot_ground_lookahead ahead has no floor.
## Styles (Phase 5, BotStyleSense): reach-scaled swings, ranged bots keep distance and shoot, a
## full gauge fires the special. Knockdowns (BotGetup): getup options and techs.
## Skill (PRD-BOT-03, BotSkill / BotDifficulty): reaction, guard / tech / DI chances, cadence,
## aim error, hesitation and special delay follow the dial d, settable every tick (DDA);
## new(id, config) without d plays the classic config bot. A BotProbe scripts the first seconds
## vs a human; intent() names the last decision (bot_intent tracking).

## Pick up when the item is this deep inside the pickup radius (a margin against rounding).
const PICKUP_REACH_RATIO := 0.8

var _self_id: int
var _config: GameConfig
var _nav: BotNav
var _cooldown: int = 0
var _combo_left: int = 0
var _defense: BotDefense
var _getup: BotGetup
var _skill: BotSkill
var _tick: int = 0
var _gauge_full_ticks: int = 0
var _log := BotIntent.new()
var probe: BotProbe = null


func _init(p_self_id: int, p_config: GameConfig, d: float = BotSkill.NO_DIAL) -> void:
	_self_id = p_self_id
	_config = p_config
	_nav = BotNav.new(p_config)
	_defense = BotDefense.new(p_self_id, p_config)
	_getup = BotGetup.new(p_self_id, p_config)
	set_skill(BotSkill.from_config(p_config) if d < 0.0 else BotDifficulty.skill(d))


## Moves the dial (DDA, probe start); takes effect on the next sample.
func set_difficulty(d: float) -> void:
	set_skill(BotDifficulty.skill(d))


func set_skill(s: BotSkill) -> void:
	_skill = s
	_defense.skill = s
	_getup.skill = s


func skill() -> BotSkill:
	return _skill


## Last decision: intent name, nearest foe id (-1 none), its distance and whether it threatened.
func intent() -> BotIntent:
	return _log


## Light presses after the first swing so hits 2 and 3 land inside the combo buffer.
static func combo_mash_ticks(config: GameConfig) -> int:
	return 2 * (config.light_startup_ticks + config.light_active_ticks + config.light_recovery_ticks)


## Swing range of bot `id`: staggered by id so mirrored bots never start the same trade forever.
static func attack_range(id: int, config: GameConfig) -> float:
	return config.bot_attack_range - config.bot_attack_range_spread * float(id % 4)


func sample(view: Dictionary) -> InputFrame:
	var sent := _sample(view)
	_defense.note(sent)
	_getup.note(sent)
	return sent


func _sample(view: Dictionary) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
	var me := BotViewQuery.find(view, _self_id)
	if me.is_empty() or int(me["state"]) == Fighter.State.KO:
		return _log.say("idle", InputFrame.neutral())
	var arena := _nav.arena_for(view)
	var my_pos: Vector3 = me["pos"]
	var foe := BotViewQuery.nearest_foe(view, _self_id, my_pos)
	_log.look(me, foe, _config.bot_guard_range)
	_gauge_full_ticks = _gauge_full_ticks + 1 if float(me.get("gauge", 0.0)) >= SpecialGauge.MAX else 0
	var safe := BotViewQuery.flat(my_pos, ArenaFloor.safe_point(arena, my_pos, _config.bot_edge_ratio)).normalized()
	# Decided every tick (even during recovery/edge/holding) so the every-other toggle never goes stale.
	_tick = int(view.get("tick", 0))
	var defense := _defense.decide(me, foe, safe, _closing(me, foe), _tick)
	var getup := _getup.decide(me, foe, _tick, arena)
	if not bool(me["on_ground"]) and my_pos.y < 0.0 and not ArenaFloor.over_floor(arena, my_pos):
		return _log.say("recover", InputFrame.make(safe.x, safe.y, int(me["jumps_left"]) > 0))
	if getup != null:
		return _log.say("getup", getup)
	if int(me["state"]) == Fighter.State.HITSTUN and _skill.di_chance > 0.0:
		return _log.say("di", _skill.di_frame(_self_id, _tick, my_pos))
	if int(me["state"]) == Fighter.State.HOLDING:
		var out := ArenaFloor.outward(arena, my_pos)
		return _log.say("throw_held", InputFrame.make(out.x, out.y, false, false, false, false, true))
	if probe != null and probe.active():
		var scripted := probe.decide(view, me, _nav, arena)
		if scripted != null:
			return _log.say("probe_" + probe.stage_name(), scripted)
	var rolling := defense != null and (defense.move_x != 0.0 or defense.move_z != 0.0)
	if safe != Vector2.ZERO and not rolling:
		return _log.say("edge", InputFrame.make(safe.x, safe.y))
	if defense != null:
		return _log.say("defend", defense)
	if _combo_left > 0:
		_combo_left -= 1
		return _log.say("combo", InputFrame.make(0, 0, false, true))
	return _act(view, me, foe, arena)


## Items first (throwables, then pickups the foe cannot also reach), otherwise fight the nearest foe.
func _act(view: Dictionary, me: Dictionary, foe: Dictionary, arena: ArenaData) -> InputFrame:
	var my_pos: Vector3 = me["pos"]
	var item_kind := int(me.get("item_kind", Fighter.NONE))
	if _skill.hesitating(_self_id, _tick):
		return _log.say("hesitate", InputFrame.neutral())
	if item_kind == Item.Kind.BOMB or item_kind == Item.Kind.ROCK:
		return _use_throwable(foe, my_pos, arena)
	if item_kind == Fighter.NONE:
		var it := BotViewQuery.nearest_item(view, my_pos, arena, _config)
		var reach := _config.item_pickup_radius * PICKUP_REACH_RATIO
		if not it.is_empty() and not BotViewQuery.contested(it, foe, reach):
			var to_item := BotViewQuery.flat(my_pos, it["pos"])
			if to_item.length() <= reach and bool(me["on_ground"]):
				if int(it["state"]) == Item.State.FALLING:
					return _log.say("item", InputFrame.neutral())  # wait under it; a grab press now would start a grab attack
				return _log.say("item", InputFrame.make(0, 0, false, false, false, false, true))
			return _log.say("item", _nav.walk(to_item.normalized(), my_pos, arena))
	return _fight(me, foe, item_kind, arena)


## A melee bot with no combo running and no special to fire, the foe not yet within its own
## swing range: the moment an early guard turn may raise its guard as the foe closes (BotDefense).
func _closing(me: Dictionary, foe: Dictionary) -> bool:
	if foe.is_empty() or _combo_left > 0 or BotStyleSense.is_ranged(me) or BotStyleSense.special_ready(me, foe, _config):
		return false
	return BotViewQuery.flat(me["pos"], foe["pos"]).length() > BotStyleSense.melee_range(me, _self_id, _config)


func _use_throwable(foe: Dictionary, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return _log.say("idle", InputFrame.neutral())
	var delta := BotViewQuery.flat(my_pos, foe["pos"])
	var dir := _skill.aim(delta.normalized() if delta.length() > 0.001 else Vector2.ZERO, _self_id, _tick)
	if delta.length() <= _config.bot_throw_range and _cooldown == 0:
		_cooldown = _skill.cooldown_ticks
		return _log.say("throw", InputFrame.make(dir.x, dir.y, false, false, false, false, true))
	return _log.say("approach", _nav.walk(dir, my_pos, arena))


func _fight(me: Dictionary, foe: Dictionary, item_kind: int, arena: ArenaData) -> InputFrame:
	if foe.is_empty():
		return _log.say("idle", InputFrame.neutral())
	var my_pos: Vector3 = me["pos"]
	var delta := BotViewQuery.flat(my_pos, foe["pos"])
	var dir := _skill.aim(delta.normalized() if delta.length() > 0.001 else Vector2.ZERO, _self_id, _tick)
	if BotStyleSense.special_ready(me, foe, _config) and _gauge_full_ticks > _skill.special_delay_ticks:
		return _log.say("special", InputFrame.make(dir.x, dir.y, false, false, true, true))
	var reach := _config.grab_forward + _config.grab_half_width + _config.fighter_radius
	if int(foe["state"]) == Fighter.State.GUARD and delta.length() <= reach:
		return _log.say("grab", InputFrame.make(dir.x, dir.y, false, false, false, false, true))
	if item_kind == Fighter.NONE and BotStyleSense.is_ranged(me):
		return _shoot(me, delta, my_pos, arena)
	if delta.length() <= BotStyleSense.melee_range(me, _self_id, _config) and _cooldown == 0:
		if BotStyleSense.has_special(me) and not BotStyleSense.aimed(me, delta):
			return _log.say("approach", InputFrame.make(dir.x, dir.y))  # an attack starts along the facing: turn first
		_cooldown = _skill.cooldown_ticks
		if item_kind != Item.Kind.BAT:
			_combo_left = combo_mash_ticks(_config)
		return _log.say("attack", InputFrame.make(dir.x, dir.y, false, true))
	return _log.say("approach", _nav.walk(dir, my_pos, arena))


## Ranged style: back off inside the keep distance (unless cornered), close in from afar, turn to
## face the foe, then fire a bolt volley.
func _shoot(me: Dictionary, delta: Vector2, my_pos: Vector3, arena: ArenaData) -> InputFrame:
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var plan := BotStyleSense.ranged_plan(me, delta, _config)
	if plan == BotStyleSense.Ranged.RETREAT:
		var away := _nav.walk(-dir, my_pos, arena)
		if away.move_x != 0.0 or away.move_z != 0.0:
			return _log.say("retreat", away)
		plan = BotStyleSense.Ranged.FIRE if BotStyleSense.aimed(me, delta) else BotStyleSense.Ranged.TURN
	if plan == BotStyleSense.Ranged.APPROACH:
		return _log.say("approach", _nav.walk(_skill.aim(dir, _self_id, _tick), my_pos, arena))
	if plan == BotStyleSense.Ranged.TURN:
		var aimed := _skill.aim(dir, _self_id, _tick)
		return _log.say("approach", InputFrame.make(aimed.x, aimed.y))
	if _cooldown > 0:
		return _log.say("shoot", InputFrame.neutral())
	_cooldown = _skill.cooldown_ticks
	_combo_left = combo_mash_ticks(_config)
	return _log.say("shoot", InputFrame.make(0, 0, false, true))
