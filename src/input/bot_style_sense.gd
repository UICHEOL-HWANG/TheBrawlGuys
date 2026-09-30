class_name BotStyleSense
extends RefCounted
## What a bot's style and special mean for its choices (PRD-BOT-02, Phase 5 T5). Reads only
## view values (the fighter view's "style", "special", "gauge", "facing") and GameConfig.
## Melee styles swing at the classic bot range times the style's reach; ranged bots keep
## bot_ranged_keep_distance, turn to face the foe, then shoot inside bot_ranged_fire_range.

enum Ranged { RETREAT, TURN, FIRE, APPROACH }

## Facing this aligned with the foe direction counts as aimed.
const AIM_DOT := 0.95


static func is_ranged(me: Dictionary) -> bool:
	return String(me.get("style", "")) == StyleCatalog.RANGED


## Swing range for bot `id` of style me["style"]. The per-id stagger (BotController.attack_range)
## only breaks endless mirrored trades of classic fighters; a character's special gauge fills
## from those trades and breaks them itself, so character bots skip the stagger (it handed
## mirror matches to one slot in the balance sim).
static func melee_range(me: Dictionary, id: int, config: GameConfig) -> float:
	var base := config.bot_attack_range if has_special(me) else BotController.attack_range(id, config)
	return base * StyleCatalog.reach_mul(String(me.get("style", "")), config)


static func has_special(me: Dictionary) -> bool:
	return not String(me.get("special", "")).is_empty()


## True when the gauge is full, the bot stands on the ground level with the foe (not falling
## in from a respawn) and the foe is inside the special's reach.
static func special_ready(me: Dictionary, foe: Dictionary, config: GameConfig) -> bool:
	var special := String(me.get("special", ""))
	if special.is_empty() or float(me.get("gauge", 0.0)) < SpecialGauge.MAX or not bool(me.get("on_ground", true)):
		return false
	var mine: Vector3 = me["pos"]
	var theirs: Vector3 = foe["pos"]
	if absf(theirs.y - mine.y) > config.fighter_height:
		return false
	var dist := Vector2(theirs.x - mine.x, theirs.z - mine.z).length()
	return dist <= SpecialCatalog.get_special(special).reach(config) * config.bot_special_reach_mul


## A ranged bot's move for a foe at `delta` (flat, from the bot to the foe).
static func ranged_plan(me: Dictionary, delta: Vector2, config: GameConfig) -> Ranged:
	var dist := delta.length()
	if dist < config.bot_ranged_keep_distance:
		return Ranged.RETREAT
	if dist > config.bot_ranged_fire_range:
		return Ranged.APPROACH
	return Ranged.FIRE if aimed(me, delta) else Ranged.TURN


## True when the fighter's facing points at `delta` (within AIM_DOT).
static func aimed(me: Dictionary, delta: Vector2) -> bool:
	if delta.length() < 0.001:
		return true
	var facing: Vector3 = me.get("facing", Vector3.FORWARD)
	return Vector2(facing.x, facing.z).normalized().dot(delta.normalized()) >= AIM_DOT
