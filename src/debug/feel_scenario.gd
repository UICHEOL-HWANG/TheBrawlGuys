class_name FeelScenario
extends RefCounted
## The feel check (PRD §1.1 "과장된 넉백"): a target standing halfway between the arena center
## and edge takes the full three-hit light combo starting at the given damage % (context E1:
## hits 1-2 are links, hit 3 is the Phase 1 light attack). Shared by the regression test and
## scripts/tune_knockback.gd so both measure the same thing.

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
	for t: int in MAX_TICKS:
		var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, combo_press(t, attacker)), InputFrame.neutral()]
		w.tick(inputs)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout" and int(e["id"]) == 1:
				return true
	return false


## Presses light on the first tick and on every tick of a chainable hit, so the combo runs to
## the finisher and stops there.
static func combo_press(t: int, attacker: Fighter) -> bool:
	return t == 0 or (attacker.state == Fighter.State.ATTACK and AttackSet.is_light_chainable(attacker.attack_kind))
