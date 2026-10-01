class_name SlotStats
extends RefCounted
## Per-slot match counters (platform A6): the match_ended "players" summary and the
## match_players row. High-frequency actions live here instead of separate Amplitude events.

const COUNTERS: Array[String] = [
	"hits", "guards", "grabs", "jumps", "whiffs", "ringouts_scored", "falls", "falls_by_gimmick",
	"specials", "special_hits", "items_used",
	# Defense and recovery (event schema 8, DefenseTelemetry)
	"hits_taken", "dodges_roll", "dodges_air", "perfect_guards", "guard_breaks",
	"guard_breaks_caused", "knockdowns", "techs", "getups_stand", "getups_roll", "getups_attack",
]
## Damage is reported in 0.1 % steps.
const DAMAGE_STEP := 0.1

var slot: int
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var _counts: Dictionary = {}


func _init(slot_index: int) -> void:
	slot = slot_index
	for c: String in COUNTERS:
		_counts[c] = 0


func add(counter: String, amount: int = 1) -> void:
	assert(_counts.has(counter), "SlotStats: unknown counter %s" % counter)
	_counts[counter] = int(_counts[counter]) + amount


func count(counter: String) -> int:
	return int(_counts.get(counter, 0))


func to_summary() -> Dictionary:
	var out := {"slot": slot, "damage_dealt": snappedf(damage_dealt, DAMAGE_STEP),
		"damage_taken": snappedf(damage_taken, DAMAGE_STEP)}
	for c: String in COUNTERS:
		out[c] = _counts[c]
	return out
