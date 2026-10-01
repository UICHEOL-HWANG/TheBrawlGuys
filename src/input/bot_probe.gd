class_name BotProbe
extends RefCounted
## The opening probe (PRD-BOT-05): for the first STAGES.size() * stage_ticks of a match a bot
## facing a human plays scripted stages against that target and ProbeObserver measures the answers:
##   frontal — walk straight in and swing (guard reaction ticks, response rate);
##   edge    — come from the arena middle and swing outward (recovery: techs, edge time);
##   ranged  — pressure from range: ranged styles fire from fire range, melee ones step in with
##             a heavy and back off (dodge rate);
##   punish  — whiff a swing away from the target at close range and stand open (punish rate).
## decide() returns null whenever the script has nothing to say (the bot plays normally), so
## recovery, getups and edge safety stay with BotController. Bot-side only: never touches the sim.

const STAGES: Array[String] = ["frontal", "edge", "ranged", "punish"]
## Cadence of scripted swings and how long the punish stage stands open after a whiff.
const SWING_EVERY := 45
const OPEN_TICKS := 50
const EDGE_SIDE := 1.0
const NEAR := 0.6
const RANGED_KEEP := 3.5
const PUNISH_DIST := 1.8

var _self_id: int
var _target: int
var _config: GameConfig
var _stage_ticks: int
var _start_tick: int = -1
var _stage: int = 0
var _next_swing: int = 0
var _open_until: int = 0
var _observer: ProbeObserver
var _results: Array[Dictionary] = []


func _init(self_id: int, target: int, config: GameConfig, stage_ticks: int) -> void:
	_self_id = self_id
	_target = target
	_config = config
	_stage_ticks = maxi(1, stage_ticks)
	_observer = ProbeObserver.new(self_id, target)


func target() -> int:
	return _target


func active() -> bool:
	return _stage < STAGES.size()


func stage_name() -> String:
	return STAGES[_stage] if active() else "done"


## Called once per sim tick after the world stepped. Returns the stage that just ended as
## {stage, result} (result = its ProbeObserver features), or {} when none ended.
func observe(view: Dictionary) -> Dictionary:
	if not active():
		return {}
	var tick := int(view.get("tick", 0))
	if _start_tick < 0:
		_start_tick = tick
	_observer.observe(view)
	if tick - _start_tick < (_stage + 1) * _stage_ticks:
		return {}
	var ended := {"stage": STAGES[_stage], "result": ProbeObserver.features(_observer.close_stage())}
	_results.append(ended)
	_stage += 1
	return ended


## Features over the whole probe (ProbeObserver.FEATURES).
func features() -> Dictionary:
	return ProbeObserver.features(_observer.total)


func stage_results() -> Array[Dictionary]:
	return _results


func decide(view: Dictionary, me: Dictionary, nav: BotNav, arena: ArenaData) -> InputFrame:
	var foe := BotViewQuery.find(view, _target)
	if foe.is_empty() or int(foe["state"]) == Fighter.State.KO or not bool(me["on_ground"]):
		return null
	var tick := int(view.get("tick", 0))
	var delta := BotViewQuery.flat(me["pos"], foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	match STAGES[_stage]:
		"frontal":
			return _close_and_swing(me, delta, dir, tick, nav, arena)
		"edge":
			return _edge(me, foe, delta, dir, tick, nav, arena)
		"ranged":
			return _ranged(me, delta, dir, tick, nav, arena)
	return _punish(me, delta, dir, tick, nav, arena)


func _ready_to_swing(tick: int) -> bool:
	if tick < _next_swing:
		return false
	_next_swing = tick + SWING_EVERY
	return true


func _close_and_swing(me: Dictionary, delta: Vector2, dir: Vector2, tick: int, nav: BotNav,
		arena: ArenaData) -> InputFrame:
	if delta.length() > BotStyleSense.melee_range(me, _self_id, _config):
		return nav.walk(dir, me["pos"], arena)
	if not BotStyleSense.aimed(me, delta):
		return InputFrame.make(dir.x, dir.y)
	return InputFrame.make(dir.x, dir.y, false, true) if _ready_to_swing(tick) else InputFrame.neutral()


## Stand on the middle side of the target, then swing outward.
func _edge(me: Dictionary, foe: Dictionary, delta: Vector2, dir: Vector2, tick: int, nav: BotNav,
		arena: ArenaData) -> InputFrame:
	var foe_pos: Vector3 = foe["pos"]
	var inward := BotViewQuery.flat(foe_pos, Vector3.ZERO).normalized()
	var spot := foe_pos + Vector3(inward.x, 0.0, inward.y) * EDGE_SIDE
	var to_spot := BotViewQuery.flat(me["pos"], spot)
	if to_spot.length() > NEAR and delta.length() > BotStyleSense.melee_range(me, _self_id, _config) * 0.6:
		return nav.walk(to_spot.normalized(), me["pos"], arena)
	return _close_and_swing(me, delta, dir, tick, nav, arena)


func _ranged(me: Dictionary, delta: Vector2, dir: Vector2, tick: int, nav: BotNav,
		arena: ArenaData) -> InputFrame:
	if BotStyleSense.is_ranged(me):
		if delta.length() < RANGED_KEEP:
			return nav.walk(-dir, me["pos"], arena)
		if delta.length() > _config.bot_ranged_fire_range:
			return nav.walk(dir, me["pos"], arena)
		if not BotStyleSense.aimed(me, delta):
			return InputFrame.make(dir.x, dir.y)
		return InputFrame.make(0, 0, false, true) if _ready_to_swing(tick) else InputFrame.neutral()
	if tick < _next_swing:
		return nav.walk(-dir, me["pos"], arena) if delta.length() < RANGED_KEEP else InputFrame.make(dir.x, dir.y)
	if delta.length() > BotStyleSense.melee_range(me, _self_id, _config):
		return nav.walk(dir, me["pos"], arena)
	_next_swing = tick + SWING_EVERY
	return InputFrame.make(dir.x, dir.y, false, false, true)


## Step to PUNISH_DIST, whiff a swing facing away, then stand open for OPEN_TICKS.
func _punish(me: Dictionary, delta: Vector2, dir: Vector2, tick: int, nav: BotNav,
		arena: ArenaData) -> InputFrame:
	if tick < _open_until:
		return InputFrame.neutral()
	if delta.length() > PUNISH_DIST:
		return nav.walk(dir, me["pos"], arena)
	if not BotStyleSense.aimed(me, -delta):
		return InputFrame.make(-dir.x, -dir.y)
	_open_until = tick + OPEN_TICKS
	_observer.mark_whiff(tick)
	return InputFrame.make(-dir.x, -dir.y, false, true)
