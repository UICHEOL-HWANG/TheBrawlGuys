class_name AttackTracker
extends RefCounted
## Swing bookkeeping from fighter views (platform A6): an attack opens when a fighter enters
## ATTACK or its attack_kind / attack_ticks restart, and closes when that ends. A closed melee
## swing that never landed (hit or guard_hit) is a whiff.

const WHIFF_KINDS: Array[int] = [
	AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3, AttackSet.Kind.HEAVY,
	AttackSet.Kind.BAT, AttackSet.Kind.HAMMER, AttackSet.Kind.GLOVE,
]

var _open: Dictionary = {}  # slot -> {"kind": int, "hit": bool}


## Compares two ticks of fighter views. Returns {"opened": [[slot, kind], ...], "whiffs": [slot, ...]}.
func observe(prev: Array, curr: Array) -> Dictionary:
	var opened: Array = []
	var whiffs: Array[int] = []
	for i: int in curr.size():
		var b: Dictionary = curr[i]
		var slot := int(b["id"])
		var a: Dictionary = prev[i] if i < prev.size() else {}
		var attacking := int(b["state"]) == Fighter.State.ATTACK
		var restarted := attacking and (int(a.get("state", -1)) != Fighter.State.ATTACK
				or int(a.get("attack_kind", -1)) != int(b["attack_kind"])
				or int(b["attack_ticks"]) < int(a.get("attack_ticks", 0)))
		if _open.has(slot) and (restarted or not attacking):
			_close(slot, whiffs)
		if restarted:
			_open[slot] = {"kind": int(b["attack_kind"]), "hit": false}
			opened.append([slot, int(b["attack_kind"])])
	return {"opened": opened, "whiffs": whiffs}


func mark_hit(slot: int) -> void:
	if _open.has(slot):
		_open[slot]["hit"] = true


## Closes every open swing (match end); returns the whiffing slots.
func close_all() -> Array[int]:
	var whiffs: Array[int] = []
	for slot: int in _open.keys():
		_close(slot, whiffs)
	return whiffs


func _close(slot: int, whiffs: Array[int]) -> void:
	var swing: Dictionary = _open[slot]
	_open.erase(slot)
	if not bool(swing["hit"]) and WHIFF_KINDS.has(int(swing["kind"])):
		whiffs.append(slot)
