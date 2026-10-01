class_name AssistFeatures
extends RefCounted
## Team assists per slot (event schema 8, team mode): a slot's hit ("hit" or "special_hit") on a
## victim that a teammate then rings out (the ringout credited to that teammate, StockLoss rules)
## within ASSIST_TICKS of the hit. Always 0 without teams.

## Three seconds at 60 Hz, the same window as ring-out credit.
const ASSIST_TICKS := StockLoss.WINDOW_TICKS
const HIT_TYPES: Array[String] = ["hit", "special_hit"]

var _hits: Dictionary = {}  # victim -> {attacker: tick of the last hit}
var _assists: Array[int] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		_assists.append(0)


## events: enriched sim events (ringouts carry the credited "attacker_slot").
## teams: slot -> team in team mode, else empty.
func observe(tick: int, events: Array, teams: Array) -> void:
	for e: Dictionary in events:
		var type := String(e["type"])
		if HIT_TYPES.has(type) and e.has("target") and e.has("attacker"):  # malformed events are skipped
			var victim := int(e["target"])
			if not _hits.has(victim):
				_hits[victim] = {}
			_hits[victim][int(e["attacker"])] = tick
		elif type == "ringout" and e.has("id"):
			_on_ringout(int(e["id"]), int(e.get("attacker_slot", -1)), tick, teams)


func summary(slot: int) -> Dictionary:
	return {"team_assists": _assists[slot]}


func _on_ringout(victim: int, scorer: int, tick: int, teams: Array) -> void:
	var hits: Dictionary = _hits.get(victim, {})
	_hits.erase(victim)
	if scorer < 0 or scorer >= teams.size():
		return
	for helper: int in hits:
		var recent := tick - int(hits[helper]) <= ASSIST_TICKS
		var teammate := helper != scorer and helper >= 0 and helper < mini(teams.size(), _assists.size()) \
				and int(teams[helper]) == int(teams[scorer])
		if recent and teammate:
			_assists[helper] += 1
