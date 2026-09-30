class_name TutorialDetector
extends RefCounted
## Did the player meet a tutorial goal this tick? (Phase 5 T11) Reads only sim views and the tick's
## events (render side, PRD §5.2 — the sim never knows about the tutorial). prev/curr are
## World.state_view() before and after the tick, input what the player sent that tick; memo is
## per-goal scratch the caller clears when the goal changes (the move goal sums distance in it).

## Metres the player has to run for the move goal.
const MOVE_DISTANCE := 4.0
## A heavy counts as charged after this much held charge (seconds of heavy_charge_max_time).
const MIN_CHARGE_S := 0.25
## A spent jump counts only this many ticks after a jump press (walking off a ledge also spends one).
const JUMP_WINDOW_TICKS := 6
const LIGHT_KINDS: Array[int] = [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3]


static func met(goal: String, prev: Dictionary, curr: Dictionary, events: Array, slot: int,
		config: GameConfig, memo: Dictionary, input: InputFrame = null) -> bool:
	var me := fighter(curr, slot)
	var before := fighter(prev, slot)
	if me.is_empty() or before.is_empty():
		return false
	match goal:
		TutorialSteps.G_MOVE:
			return _moved(before, me, memo)
		TutorialSteps.G_JUMP:
			return _jumped(before, me, input, memo)
		TutorialSteps.G_LIGHT_HIT:
			return _hit_with(events, slot, LIGHT_KINDS, 0.0)
		TutorialSteps.G_CHARGED_HIT:
			var charged := Actions.charge_mul(SimTime.to_ticks(MIN_CHARGE_S), config)
			return _hit_with(events, slot, [AttackSet.Kind.HEAVY] as Array[int], charged)
		TutorialSteps.G_GUARD:
			return _any(events, "guard_hit", "target", slot) or _any(events, "perfect_guard", "fighter", slot)
		TutorialSteps.G_GRAB:
			return _any(events, "grab", "attacker", slot)
		TutorialSteps.G_THROW:
			return _hit_with(events, slot, [AttackSet.Kind.THROW] as Array[int], 0.0)
		TutorialSteps.G_PICKUP:
			return _any(events, "item_pickup", "fighter", slot)
		TutorialSteps.G_ITEM_USE:
			return _any(events, "item_throw", "fighter", slot) or _swung_bat(before, me)
		TutorialSteps.G_SPECIAL:
			return _any(events, "special_start", "fighter", slot)
	push_warning("TutorialDetector: unknown goal '%s'" % goal)
	return false


static func fighter(view: Dictionary, slot: int) -> Dictionary:
	for f: Dictionary in view.get("fighters", []):
		if int(f.get("id", -1)) == slot:
			return f
	return {}


## Running distance on the ground plane; a respawn (new spawn_id) is a teleport, not a run.
static func _moved(before: Dictionary, me: Dictionary, memo: Dictionary) -> bool:
	if int(me["spawn_id"]) == int(before["spawn_id"]):
		var a: Vector3 = before["pos"]
		var b: Vector3 = me["pos"]
		memo["distance"] = float(memo.get("distance", 0.0)) + Vector2(b.x - a.x, b.z - a.z).length()
	return float(memo.get("distance", 0.0)) >= MOVE_DISTANCE


## The grab ended without a throw (the hold timed out): the throw goal goes back to the grab.
static func grab_lost(events: Array, slot: int) -> bool:
	return _any(events, "grab_release", "attacker", slot)


## A jump spent within JUMP_WINDOW_TICKS of a jump press.
static func _jumped(before: Dictionary, me: Dictionary, input: InputFrame, memo: Dictionary) -> bool:
	var window := JUMP_WINDOW_TICKS if input != null and input.jump else int(memo.get("jump_window", 0))
	memo["jump_window"] = maxi(window - 1, 0)
	return window > 0 and int(me["jumps_left"]) < int(before["jumps_left"])


## The player's own melee hit of one of these attack kinds with at least min_power (charge).
static func _hit_with(events: Array, slot: int, kinds: Array[int], min_power: float) -> bool:
	for e: Dictionary in events:
		if e.get("type") == "hit" and int(e.get("attacker", -1)) == slot \
				and kinds.has(int(e.get("attack_kind", -1))) and float(e.get("power", 1.0)) >= min_power:
			return true
	return false


## A bat swing starts (the bat stays in hand, so there is no throw event).
static func _swung_bat(before: Dictionary, me: Dictionary) -> bool:
	var swinging := int(me["state"]) == Fighter.State.ATTACK and int(me["attack_kind"]) == AttackSet.Kind.BAT
	var was := int(before["state"]) == Fighter.State.ATTACK and int(before["attack_kind"]) == AttackSet.Kind.BAT
	return swinging and not was


static func _any(events: Array, type: String, key: String, slot: int) -> bool:
	for e: Dictionary in events:
		if e.get("type") == type and int(e.get(key, -1)) == slot:
			return true
	return false
