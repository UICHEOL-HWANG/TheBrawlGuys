extends "res://src/main/main.gd"
## Phase 1 evidence scene: the bot stands at 100% halfway to the edge and the player lands one
## light attack at tick 60. Used for the ring-out video and key frames (PHASES Phase 1).

const DEMO_DAMAGE := 100.0
const SWING_TICK := 60


func _start_match() -> void:
	super._start_match()
	var w := get_world()
	var target := w.fighters[BOT_PLAYER]
	target.pos = Vector3(w.config.arena_radius * FeelScenario.TARGET_DISTANCE_RATIO, 0, 0)
	target.damage = DEMO_DAMAGE
	target.facing = Vector3(-1, 0, 0)
	var attacker := w.fighters[LOCAL_PLAYER]
	attacker.pos = target.pos - Vector3(FeelScenario.ATTACKER_GAP, 0, 0)
	attacker.facing = Vector3(1, 0, 0)


func _gather_inputs() -> Array[InputFrame]:
	var swing := get_world().tick_count == SWING_TICK
	var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, swing), InputFrame.neutral()]
	return inputs
