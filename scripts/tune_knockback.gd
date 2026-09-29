extends SceneTree
## Sweeps global_knockback_mul over FeelScenario (the 3-hit combo at 100% damage) and prints the
## contiguous window(s) where the target rings out. The result is NOT monotonic: too high a
## multiplier launches the target out of reach of the finisher, so ring-out only happens inside a
## window. Exits 1 if the default is outside every window or if the default rings out at 0%.
## Run: godot --headless --path . -s res://scripts/tune_knockback.gd

const SWEEP_MIN := 0.5
const SWEEP_MAX := 4.0
const SWEEP_STEP := 0.05


func _init() -> void:
	var windows := _windows()
	if windows.is_empty():
		push_error("tune_knockback: no multiplier in %.2f..%.2f rings out at 100%%" % [SWEEP_MIN, SWEEP_MAX])
		quit(1)
		return
	for w: Vector2 in windows:
		print("tune_knockback: ring-out window at 100%%: %.2f .. %.2f" % [w.x, w.y])
	var default_mul := GameConfig.new().global_knockback_mul
	var in_window := false
	for w: Vector2 in windows:
		if default_mul >= w.x - 0.0001 and default_mul <= w.y + 0.0001:
			in_window = true
			var fraction := (default_mul - w.x) / maxf(w.y - w.x, 0.0001)
			print("tune_knockback: default %.2f sits %.0f%% of the way through its window" % [default_mul, fraction * 100.0])
	var stays_on_stage := not _rings(default_mul, 0.0)
	print("tune_knockback: 0%% stays on stage at the default: %s" % str(stays_on_stage))
	if not in_window:
		push_error("tune_knockback: default %.2f is outside every ring-out window" % default_mul)
	quit(0 if in_window and stays_on_stage else 1)


## Contiguous [first, last] ranges of swept multipliers that ring out at 100%.
func _windows() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := -1.0
	var last := -1.0
	var steps := int(round((SWEEP_MAX - SWEEP_MIN) / SWEEP_STEP))
	for i: int in steps + 1:
		var mul := SWEEP_MIN + i * SWEEP_STEP
		if _rings(mul, 100.0):
			if start < 0.0:
				start = mul
			last = mul
		elif start >= 0.0:
			result.append(Vector2(start, last))
			start = -1.0
	if start >= 0.0:
		result.append(Vector2(start, last))
	return result


func _rings(mul: float, damage: float) -> bool:
	var c := GameConfig.new()
	c.global_knockback_mul = mul
	return FeelScenario.rings_out(c, damage)
