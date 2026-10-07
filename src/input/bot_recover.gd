class_name BotRecover
extends RefCounted
## A bot's way back from off the arena (next-polish 1, PRD §6.4). Bot ring-outs were launches the
## bot never fought: it jumped only after dropping under the floor top, too late to land, and
## never air-dodged. Now, airborne and not over any floor: steer home, take the air jump at the
## apex (not while still rising), and once the jump is spent air-dodge toward the floor when the
## dodge's reach covers the gap and the hover starts above the floor top. A launch (hitstun) is
## left to DI. Whether a fall is fought this way is rolled once per fall on recover_chance
## (BotSkill; the dial lowers it); otherwise the old habit (jump once under the floor top).
## Reads view values only; its vertical motion and the guard press it keeps itself.

## A dodge covers air_dodge_distance; it must start a little inside that to land.
const DODGE_REACH_RATIO := 0.85
## The air dodge hovers at its start height: start above the floor top or it can never land.
const DODGE_MIN_Y := 0.05
## States the bot can steer from (the sim turns IDLE / MOVE off the floor into AIR).
const FREE: Array[int] = [Fighter.State.AIR, Fighter.State.IDLE, Fighter.State.MOVE]
enum Plan { UNSET, FIGHT, HABIT }

var _config: GameConfig
var _last_y: float = INF
var _plan: int = Plan.UNSET
## The guard was sent last tick: a dodge needs a new press, so it is let go in between.
var _guard_sent: bool = false


func _init(p_config: GameConfig) -> void:
	_config = p_config


## The frame that brings me back, or null when there is nothing to recover from.
func decide(me: Dictionary, arena: ArenaData, home: Vector2, skill: BotSkill, tick: int) -> InputFrame:
	var pos: Vector3 = me["pos"]
	var rising := pos.y > _last_y
	_last_y = pos.y
	if bool(me["on_ground"]) or ArenaFloor.over_floor(arena, pos):
		_reset()
		return null
	if _plan == Plan.UNSET:
		_plan = Plan.FIGHT if skill.recovers(int(me["id"]), tick) else Plan.HABIT
	var jumps := int(me["jumps_left"]) > 0
	if _plan == Plan.HABIT:
		return InputFrame.make(home.x, home.y, jumps) if pos.y < 0.0 else null
	if not FREE.has(int(me["state"])):
		return null  # a launch (DI), a dodge already under way or an attack: not ours to steer
	var dodge := not jumps and _can_dodge(me, arena, pos)
	var press := dodge and not _guard_sent
	_guard_sent = press
	if jumps and not rising:
		return InputFrame.make(home.x, home.y, true)
	return InputFrame.make(home.x, home.y, false, false, false, press)


func _reset() -> void:
	_plan = Plan.UNSET
	_guard_sent = false
	_last_y = INF


func _can_dodge(me: Dictionary, arena: ArenaData, pos: Vector3) -> bool:
	if bool(me.get("air_dodge_used", true)) or pos.y < DODGE_MIN_Y:
		return false
	var gap := -ArenaFloor.edge_distance(arena, pos)
	return gap <= _config.air_dodge_distance * DODGE_REACH_RATIO
