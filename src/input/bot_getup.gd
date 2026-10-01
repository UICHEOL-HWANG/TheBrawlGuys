class_name BotGetup
extends RefCounted
## A bot's knockdown play (combat-depth C), split out of BotController. Lying (KNOCKDOWN), it
## picks one option per knockdown — stand up, roll away from the foe (toward the middle when that
## would leave safe ground), getup attack when the foe is within reach, or stay down — and holds
## it until the sim lets it act. Tumbling, it decides once per launch (bot_tech_chance) whether
## to tech, then presses guard once while falling within bot_tech_height of the floor.
## Choices are deterministic: a hash of the view tick and the bot id (bots never read the sim RNG).

enum Option { STAND, ROLL, ATTACK, WAIT }

## Extra reach over getup_attack_radius before the getup attack is worth swinging.
const ATTACK_REACH_PAD := 0.3
const OPTION_SALT := 17
const TECH_SALT := 31

var _self_id: int
var _config: GameConfig
var _choice: int = -1
var _launch_seen: bool = false
var _plan_tech: bool = false
var _last_y: float = 0.0


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


## A frame for a lying or tumbling bot, or null to let the usual logic run. Call every sample.
func decide(me: Dictionary, foe: Dictionary, tick: int, arena: ArenaData) -> InputFrame:
	var pos: Vector3 = me["pos"]
	var falling := pos.y < _last_y
	_last_y = pos.y
	if int(me["state"]) == Fighter.State.KNOCKDOWN:
		if _choice < 0:
			_choice = posmod(hash([_self_id, tick, OPTION_SALT]), Option.size())
		return _option(me, foe, arena)
	_choice = -1
	if not bool(me.get("tumbling", false)):
		_launch_seen = false
		return null
	if not _launch_seen:
		_launch_seen = true
		_plan_tech = posmod(hash([_self_id, tick, TECH_SALT]), 100) < int(_config.bot_tech_chance * 100.0)
	if _plan_tech and falling and _near_floor(pos, arena):
		_plan_tech = false
		return InputFrame.make(0, 0, false, false, false, true)
	return null


func _option(me: Dictionary, foe: Dictionary, arena: ArenaData) -> InputFrame:
	var pos: Vector3 = me["pos"]
	match _choice:
		Option.WAIT:
			return InputFrame.neutral()
		Option.ATTACK:
			var reach := _config.getup_attack_radius + _config.fighter_radius + ATTACK_REACH_PAD
			if not foe.is_empty() and BotViewQuery.flat(pos, foe["pos"]).length() <= reach:
				return InputFrame.make(0, 0, false, true)
		Option.ROLL:
			var dir := _roll_dir(pos, foe, arena)
			if dir != Vector2.ZERO:
				return InputFrame.make(dir.x, dir.y)
	return InputFrame.make(0, 0, true)  # stand up


## Away from the foe, unless that ends off safe ground: then toward the arena middle.
func _roll_dir(pos: Vector3, foe: Dictionary, arena: ArenaData) -> Vector2:
	var away := Vector2.ZERO
	if not foe.is_empty():
		away = -BotViewQuery.flat(pos, foe["pos"]).normalized()
	var end := pos + Vector3(away.x, 0.0, away.y) * _config.getup_roll_distance
	if away != Vector2.ZERO and BotViewQuery.is_safe(arena, Vector3(end.x, 0.0, end.z), _config):
		return away
	return BotViewQuery.flat(pos, Vector3.ZERO).normalized()


func _near_floor(pos: Vector3, arena: ArenaData) -> bool:
	var top := ArenaFloor.ground_top(arena, pos, pos.y)
	return top != ArenaFloor.NO_GROUND and pos.y - top <= _config.bot_tech_height
