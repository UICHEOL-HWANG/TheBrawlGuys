extends RefCounted
## Synthetic sim ticks for tutorial tests: minimal state_view() shapes (player slot 0, dummy slot 1)
## and, per goal, a tick {prev, curr, events, input} that meets it.

const PLAYER := 0
const DUMMY := 1
const CHARGED_POWER := 3.0


static func fighter(id: int, extra: Dictionary = {}) -> Dictionary:
	var f := {"id": id, "pos": Vector3(id * 3.0, 0.0, 0.0), "spawn_id": 0, "jumps_left": 2,
		"state": Fighter.State.IDLE, "attack_kind": AttackSet.Kind.LIGHT_1}
	return f.merged(extra, true)


static func view(me: Dictionary = {}) -> Dictionary:
	return {"fighters": [fighter(PLAYER, me), fighter(DUMMY)], "items": [], "events": []}


static func idle() -> Dictionary:
	return view()


static func attacking(kind: int) -> Dictionary:
	return view({"state": Fighter.State.ATTACK, "attack_kind": kind})


static func met(goal: String) -> Dictionary:
	var prev := idle()
	var curr := idle()
	var events: Array = []
	var input := InputFrame.neutral()
	match goal:
		TutorialSteps.G_MOVE:
			curr = view({"pos": Vector3(TutorialDetector.MOVE_DISTANCE + 1.0, 0.0, 0.0)})
		TutorialSteps.G_JUMP:
			curr = view({"jumps_left": 1, "state": Fighter.State.AIR})
			input = InputFrame.make(0.0, 0.0, true)
		TutorialSteps.G_LIGHT_HIT:
			curr = attacking(AttackSet.Kind.LIGHT_1)
			events = [{"type": "hit", "attacker": PLAYER, "target": DUMMY, "power": 1.0,
				"attack_kind": AttackSet.Kind.LIGHT_1}]
		TutorialSteps.G_CHARGED_HIT:
			curr = attacking(AttackSet.Kind.HEAVY)
			events = [{"type": "hit", "attacker": PLAYER, "target": DUMMY, "power": CHARGED_POWER,
				"attack_kind": AttackSet.Kind.HEAVY}]
		TutorialSteps.G_GUARD:
			events = [{"type": "guard_hit", "attacker": DUMMY, "target": PLAYER}]
		TutorialSteps.G_GRAB:
			events = [{"type": "grab", "attacker": PLAYER, "target": DUMMY}]
		TutorialSteps.G_THROW:
			events = [{"type": "hit", "attacker": PLAYER, "target": DUMMY, "attack_kind": AttackSet.Kind.THROW}]
		TutorialSteps.G_PICKUP:
			events = [{"type": "item_pickup", "fighter": PLAYER, "kind": Item.Kind.BAT}]
		TutorialSteps.G_ITEM_USE:
			events = [{"type": "item_throw", "fighter": PLAYER, "kind": Item.Kind.BAT}]
		TutorialSteps.G_SPECIAL:
			events = [{"type": "special_start", "fighter": PLAYER}]
	curr["events"] = events
	return {"prev": prev, "curr": curr, "events": events, "input": input}
