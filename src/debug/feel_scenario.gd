class_name FeelScenario
extends RefCounted
## The Phase 1 feel check (PRD §1.1 "과장된 넉백"): a target standing halfway between the
## arena center and edge takes one light attack at the given damage %. Shared by the
## regression test and scripts/tune_knockback.gd so both measure the same thing.

const TARGET_DISTANCE_RATIO := 0.5
const MAX_TICKS := 600
const ATTACKER_GAP := 1.0


static func rings_out(config: GameConfig, damage: float) -> bool:
	var w := World.new(config, 1)
	var target := w.fighters[1]
	target.pos = Vector3(config.arena_radius * TARGET_DISTANCE_RATIO, 0, 0)
	target.damage = damage
	var attacker := w.fighters[0]
	attacker.pos = target.pos - Vector3(ATTACKER_GAP, 0, 0)
	attacker.facing = Vector3(1, 0, 0)
	var swing: Array[InputFrame] = [InputFrame.make(0, 0, false, true), InputFrame.neutral()]
	w.tick(swing)
	var idle: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	for i: int in MAX_TICKS:
		w.tick(idle)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout" and int(e["id"]) == 1:
				return true
	return false
