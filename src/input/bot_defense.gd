class_name BotDefense
extends RefCounted
## A bot's guard and roll decisions (combat-depth A), split out of BotController. A threat is the
## nearest foe attacking or charging within bot_guard_range. bot_guard_react_ticks after a new
## threat the bot reacts (never frame-perfect, so it rarely perfect-guards): every other threat
## it guards for bot_guard_ticks (unless its guard meter is under bot_guard_min_ratio); on the
## other turns it rolls — toward the middle when on the edge, away from a charging foe — and
## otherwise lets it come. A roll needs a fresh guard press, so note() records what was sent.
## Reacting to a fast swing always lands inside the perfect-guard window, so only
## bot_perfect_guard_chance of the guard turns react to one in time (combat-depth C). On the
## others the bot anticipates: a foe moving in within bot_guard_range while still outside the
## bot's own swing range makes it raise its guard before the swing (once per turn), a plain
## block; missing that, it is too slow for the swing (a charge it still guards, never perfectly).
## Which turns is deterministic (a hash of the bot id, its guard-turn count and the view tick).
## The reaction delay and chances come from `skill` (BotSkill, the difficulty dial); a threat the
## skill does not answer (guard_chance) gets no reaction at all.

const EARLY_SALT := 53
## The foe counts as moving in when it got at least this much closer since the last sample (m).
const APPROACH_EPSILON := 0.001

var _self_id: int
var _config: GameConfig
## Reaction delay and guard chances (BotDifficulty); BotController swaps it when d changes.
var skill: BotSkill
var _guard_left: int = 0
## Samples until the bot reacts to the current threat (0 = nothing pending).
var _react_left: int = 0
var _react_guard: bool = false
var _react_heavy: bool = false
## This guard turn reacts too late for a fast swing (an anticipating turn).
var _react_late: bool = false
var _guard_next_threat: bool = true
var _foe_was_threat: bool = false
var _guard_was: bool = false
## The coming guard turn raises the guard early; guard turns counted so far; it already did.
var _early_next: bool = false
var _guard_turns: int = 0
var _early_done: bool = false
var _foe_dist_was: float = INF
var _tick: int = 0


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config
	skill = BotSkill.from_config(p_config)
	_early_next = _roll_early()


## Called every sample (also on edge / recovery ticks, so the every-other toggle never goes
## stale). Returns a guard or roll frame, or null for "no defense this tick". safe is the
## bot's way back from the edge (zero when not on the edge); closing = the foe is coming but not
## yet within the bot's own swing range (an early guard may start); tick = the view tick (varies
## which turns anticipate from match to match).
func decide(me: Dictionary, foe: Dictionary, safe: Vector2, closing: bool = false, tick: int = 0) -> InputFrame:
	_tick = tick
	var my_pos: Vector3 = me["pos"]
	var threat := _is_threat(foe, my_pos)
	var dist := BotViewQuery.flat(my_pos, foe["pos"]).length() if not foe.is_empty() else INF
	if closing and not threat and is_finite(_foe_dist_was) and dist < _foe_dist_was - APPROACH_EPSILON:
		_guard_early(me, dist)
	_foe_dist_was = dist
	if threat and not _foe_was_threat:
		_new_threat(foe)
	_foe_was_threat = threat
	if _react_left > 0:
		_react_left -= 1
		if _react_left == 0:
			var roll := _react(me, foe, safe)
			if roll != null:
				return roll
	if _guard_left > 0:
		_guard_left -= 1
		if float(me.get("guard_hp_ratio", 1.0)) >= _config.bot_guard_min_ratio:
			return InputFrame.make(0, 0, false, false, false, true)
		_guard_left = 0
	return null


## What the bot actually sent this tick.
func note(sent: InputFrame) -> void:
	_guard_was = sent.guard


## A foe just started attacking or charging in range: plan the reaction, flip the turn.
func _new_threat(foe: Dictionary) -> void:
	_react_left = skill.react_ticks + 1 if skill.answers_threat(_self_id, _tick) else 0
	_react_guard = _guard_next_threat
	_react_heavy = int(foe["state"]) == Fighter.State.CHARGE
	_react_late = _early_next and not _react_heavy
	_guard_next_threat = not _guard_next_threat
	if _guard_next_threat:
		_early_next = _roll_early()
		_early_done = false


## On an early guard turn, a foe moving in within bot_guard_range (not swinging yet) starts the guard.
func _guard_early(me: Dictionary, dist: float) -> void:
	if not _guard_next_threat or not _early_next or _early_done or _guard_left > 0:
		return
	if not skill.answers_threat(_self_id, _guard_turns):
		return
	if bool(me["on_ground"]) and dist <= _config.bot_guard_range:
		_guard_left = _config.bot_guard_ticks
		_early_done = true


## Whether the next guard turn guards early (a plain block) rather than on reaction.
func _roll_early() -> bool:
	_guard_turns += 1
	var roll := posmod(hash([_self_id, _guard_turns, _tick, EARLY_SALT]), 100)
	return roll >= int(skill.perfect_guard_chance * 100.0)


func _is_threat(foe: Dictionary, my_pos: Vector3) -> bool:
	if foe.is_empty() or BotViewQuery.flat(my_pos, foe["pos"]).length() > _config.bot_guard_range:
		return false
	var s := int(foe["state"])
	return s == Fighter.State.ATTACK or s == Fighter.State.CHARGE


## The reaction: start guarding (null, the guard frames follow), or a roll frame.
func _react(me: Dictionary, foe: Dictionary, safe: Vector2) -> InputFrame:
	if _react_guard:
		if not _react_late:
			_guard_left = _config.bot_guard_ticks
		return null
	if _guard_was or not bool(me["on_ground"]):
		return null
	var dir := safe
	if dir == Vector2.ZERO and _react_heavy and not foe.is_empty():
		dir = -BotViewQuery.flat(me["pos"], foe["pos"]).normalized()
	if dir == Vector2.ZERO:
		return null
	return InputFrame.make(dir.x, dir.y, false, false, false, true)
