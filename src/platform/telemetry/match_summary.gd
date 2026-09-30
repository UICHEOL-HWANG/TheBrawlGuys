class_name MatchSummary
extends RefCounted
## Small pure helpers for MatchTelemetry (platform A6): results, durations and view lookups.

## Duration precision in seconds.
const SECONDS_STEP := 0.01
const VICTIM_KEYS: Array[String] = ["target", "fighter", "victim"]


## "win" | "loss" | "draw" | "abandoned" for one slot. winner is a slot or null.
static func result(slot: int, over: bool, winner: Variant) -> String:
	if not over:
		return "abandoned"
	if winner == null:
		return "draw"
	return "win" if int(winner) == slot else "loss"


static func seconds(ticks: int) -> float:
	return snappedf(float(ticks) / SimTime.TICK_RATE, SECONDS_STEP)


static func stocks_left(view: Dictionary, slot: int) -> int:
	for f: Dictionary in view.get("fighters", []):
		if int(f["id"]) == slot:
			return int(f["stocks"])
	return 0


## Damage a fighter had in the last view before this tick (its damage at death on a ringout).
static func damage_of(fighters: Array, slot: int) -> float:
	for f: Dictionary in fighters:
		if int(f["id"]) == slot:
			return float(f["damage"])
	return 0.0


## Fighter touched by an arena event (target / fighter / victim key), or -1.
static func fighter_of(e: Dictionary) -> int:
	for k: String in VICTIM_KEYS:
		if e.has(k):
			return int(e[k])
	return -1
