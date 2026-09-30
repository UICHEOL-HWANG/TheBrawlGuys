class_name BotDefense
extends RefCounted
## A bot's guard and roll decisions (combat-depth A), split out of BotController. A threat is the
## nearest foe attacking or charging within bot_guard_range. bot_guard_react_ticks after a new
## threat the bot reacts (never frame-perfect, so it rarely perfect-guards): every other threat
## it guards for bot_guard_ticks (unless its guard meter is under bot_guard_min_ratio); on the
## other turns it rolls — toward the middle when on the edge, away from a charging foe — and
## otherwise lets it come. A roll needs a fresh guard press, so note() records what was sent.

var _config: GameConfig
var _guard_left: int = 0
## Samples until the bot reacts to the current threat (0 = nothing pending).
var _react_left: int = 0
var _react_guard: bool = false
var _react_heavy: bool = false
var _guard_next_threat: bool = true
var _foe_was_threat: bool = false
var _guard_was: bool = false


func _init(p_config: GameConfig) -> void:
	_config = p_config


## Called every sample (also on edge / recovery ticks, so the every-other toggle never goes
## stale). Returns a guard or roll frame, or null for "no defense this tick". safe is the
## bot's way back from the edge (zero when not on the edge).
func decide(me: Dictionary, foe: Dictionary, safe: Vector2) -> InputFrame:
	var my_pos: Vector3 = me["pos"]
	var threat := _is_threat(foe, my_pos)
	if threat and not _foe_was_threat:
		_react_left = _config.bot_guard_react_ticks + 1
		_react_guard = _guard_next_threat
		_react_heavy = int(foe["state"]) == Fighter.State.CHARGE
		_guard_next_threat = not _guard_next_threat
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


func _is_threat(foe: Dictionary, my_pos: Vector3) -> bool:
	if foe.is_empty() or BotViewQuery.flat(my_pos, foe["pos"]).length() > _config.bot_guard_range:
		return false
	var s := int(foe["state"])
	return s == Fighter.State.ATTACK or s == Fighter.State.CHARGE


## The reaction: start guarding (null, the guard frames follow), or a roll frame.
func _react(me: Dictionary, foe: Dictionary, safe: Vector2) -> InputFrame:
	if _react_guard:
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
