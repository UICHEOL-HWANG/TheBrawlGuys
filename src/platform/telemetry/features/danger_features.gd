class_name DangerFeatures
extends RefCounted
## Choices under danger per slot (event schema 8): guard presses, attack presses (light or heavy,
## once per tick) and dodges (sim "dodge") made while at the edge (past SpatialFeatures.EDGE_RATIO
## of the arena radius) or at HIGH_DAMAGE % or more, read from the view before the choice.
## high_dmg_ticks: living ticks spent at HIGH_DAMAGE or more (the denominator for those choices;
## edge time is edge_time_ratio).

const HIGH_DAMAGE := 100.0
const CHOICES: Array[String] = ["guard_presses", "attack_presses", "dodges"]
const PREFIXES: Array[String] = ["edge_", "high_dmg_"]

var _slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		var s := {"high_dmg_ticks": 0}
		for prefix: String in PREFIXES:
			for choice: String in CHOICES:
				s[prefix + choice] = 0
		_slots.append(s)


## presses: per slot {"guard": bool, "attack": bool} rising edges this tick (empty without inputs).
func observe(events: Array, prev: Array, arena_radius: float, presses: Array) -> void:
	for i: int in mini(prev.size(), _slots.size()):
		if _alive(prev[i]) and float(prev[i]["damage"]) >= HIGH_DAMAGE:
			_slots[i]["high_dmg_ticks"] = int(_slots[i]["high_dmg_ticks"]) + 1
	for i: int in mini(mini(presses.size(), prev.size()), _slots.size()):
		if bool(presses[i]["guard"]):
			_note(i, prev[i], arena_radius, "guard_presses")
		if bool(presses[i]["attack"]):
			_note(i, prev[i], arena_radius, "attack_presses")
	for e: Dictionary in events:
		var slot := int(e.get("fighter", -1))
		if String(e["type"]) == "dodge" and slot >= 0 and slot < mini(prev.size(), _slots.size()):
			_note(slot, prev[slot], arena_radius, "dodges")


func summary(slot: int) -> Dictionary:
	return _slots[slot].duplicate()


func _note(slot: int, view: Dictionary, arena_radius: float, choice: String) -> void:
	if not _alive(view):
		return
	var pos: Vector3 = view["pos"]
	if Vector2(pos.x, pos.z).length() > SpatialFeatures.EDGE_RATIO * arena_radius:
		_slots[slot]["edge_" + choice] = int(_slots[slot]["edge_" + choice]) + 1
	if float(view["damage"]) >= HIGH_DAMAGE:
		_slots[slot]["high_dmg_" + choice] = int(_slots[slot]["high_dmg_" + choice]) + 1


static func _alive(view: Dictionary) -> bool:
	return int(view["state"]) != Fighter.State.KO
