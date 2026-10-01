class_name BotSkill
extends RefCounted
## One bot's skill parameters (PRD-BOT-03): what the difficulty dial (BotDifficulty) sets and the
## bot reads every tick, so DDA can change them mid-match. from_config() reproduces the classic
## config-driven bot exactly (no hesitation, no aim error, every threat answered).
## The noise helpers are deterministic: a hash of the bot id, a time window and a salt — bots
## never read the sim RNG, so replays and the sim stay untouched.

## Ticks one hesitation / aim-error roll lasts (so a bot hesitates or misaims for a stretch).
const WINDOW_TICKS := 24
const HESITATE_SALT := 71
const AIM_SALT := 73
const DI_SALT := 79
const GUARD_SALT := 83
const GETUP_SALT := 89
## d of a skill built from config (no dial).
const NO_DIAL := -1.0

var d: float = NO_DIAL
## Sim ticks between a threat and the bot's reaction to it.
var react_ticks: int = 1
## Share of threats the bot answers at all (guard or roll); the rest it ignores.
var guard_chance: float = 1.0
var perfect_guard_chance: float = 0.35
var tech_chance: float = 0.35
## Share of knockdowns where it picks the sensible getup (roll away / attack in reach) over a random one.
var smart_getup: float = 0.0
## Share of launches it holds DI toward the arena middle.
var di_chance: float = 0.0
var cooldown_ticks: int = 30
## Largest aim error (degrees) applied to its approach and swing direction.
var aim_error_deg: float = 0.0
## Share of WINDOW_TICKS windows it stands still instead of pressing the attack.
var hesitate_chance: float = 0.0
## Ticks it waits with a full gauge before firing the special.
var special_delay_ticks: int = 0


static func from_config(config: GameConfig) -> BotSkill:
	var s := BotSkill.new()
	s.react_ticks = config.bot_guard_react_ticks
	s.perfect_guard_chance = config.bot_perfect_guard_chance
	s.tech_chance = config.bot_tech_chance
	s.cooldown_ticks = config.bot_attack_cooldown_ticks
	return s


func to_dict() -> Dictionary:
	return {"d": d, "react_ticks": react_ticks, "guard_chance": guard_chance,
		"perfect_guard_chance": perfect_guard_chance, "tech_chance": tech_chance, "smart_getup": smart_getup,
		"di_chance": di_chance, "cooldown_ticks": cooldown_ticks, "aim_error_deg": aim_error_deg,
		"hesitate_chance": hesitate_chance, "special_delay_ticks": special_delay_ticks}


## Hash of the parameters: two bots with the same hash play the same way.
func params_hash() -> int:
	return hash(to_dict())


## Deterministic roll in [0, 1) for (id, tick, salt).
static func roll(id: int, tick: int, salt: int) -> float:
	return float(posmod(hash([id, tick, salt]), 10000)) / 10000.0


func hesitating(id: int, tick: int) -> bool:
	return hesitate_chance > 0.0 and roll(id, tick / WINDOW_TICKS, HESITATE_SALT) < hesitate_chance


## dir turned by this window's aim error (up to aim_error_deg either way).
func aim(dir: Vector2, id: int, tick: int) -> Vector2:
	if aim_error_deg <= 0.0 or dir == Vector2.ZERO:
		return dir
	var r := roll(id, tick / WINDOW_TICKS, AIM_SALT) * 2.0 - 1.0
	return dir.rotated(deg_to_rad(aim_error_deg * r))


func answers_threat(id: int, tick: int) -> bool:
	return guard_chance >= 1.0 or roll(id, tick, GUARD_SALT) < guard_chance


func uses_di(id: int, tick: int) -> bool:
	return roll(id, tick, DI_SALT) < di_chance


## Launched at my_pos: DI toward the arena middle on di_chance of the launch windows, else neutral.
func di_frame(id: int, tick: int, my_pos: Vector3) -> InputFrame:
	if not uses_di(id, tick / WINDOW_TICKS):
		return InputFrame.neutral()
	var home := BotViewQuery.flat(my_pos, Vector3.ZERO).normalized()
	return InputFrame.make(home.x, home.y)


func smart_getup_now(id: int, tick: int) -> bool:
	return roll(id, tick, GETUP_SALT) < smart_getup
