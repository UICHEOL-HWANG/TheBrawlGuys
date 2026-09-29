extends SceneTree
## Finds the smallest global_knockback_mul for which FeelScenario rings out at 100%, and checks
## the same value keeps a 0% hit on stage. Prints a recommended default with a safety margin.
## Run: godot --headless --path . -s res://scripts/tune_knockback.gd

const LOW := 0.5
const HIGH := 10.0
const ITERATIONS := 20
const SAFETY := 1.15
const ROUND_TO := 0.05


func _init() -> void:
	var lo := LOW
	var hi := HIGH
	if not _rings(hi, 100.0):
		push_error("tune_knockback: even %.2f does not ring out at 100%%" % hi)
		quit(1)
		return
	for i: int in ITERATIONS:
		var mid := (lo + hi) * 0.5
		if _rings(mid, 100.0):
			hi = mid
		else:
			lo = mid
	var recommended := snappedf(hi * SAFETY, ROUND_TO)
	print("tune_knockback: minimum %.3f, recommended %.2f" % [hi, recommended])
	print("tune_knockback: 0%% stays on stage at recommended: %s" % str(not _rings(recommended, 0.0)))
	quit(0)


func _rings(mul: float, damage: float) -> bool:
	var c := GameConfig.new()
	c.global_knockback_mul = mul
	return FeelScenario.rings_out(c, damage)
