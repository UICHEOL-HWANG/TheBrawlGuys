class_name SpecialGauge
extends RefCounted
## The special gauge (PRD §6.2.1): after all of a tick's hits, each fighter gains
## special_gauge_per_damage_dealt per % it dealt and special_gauge_per_damage_taken per % it took
## (hits, guarded hits and gimmick damage), capped at MAX. Hits of a special never refill its
## own user. Reaching MAX emits gauge_full {fighter}. The gauge survives ring-outs.

const MAX := 100.0


static func apply(fighters: Array[Fighter], events: Array[Dictionary], config: GameConfig) -> Array[Dictionary]:
	var was_full: Array[bool] = []
	for f: Fighter in fighters:
		was_full.append(f.gauge >= MAX)
	for e: Dictionary in events:
		_gain_from(e, fighters, config)
	var out: Array[Dictionary] = []
	for f: Fighter in fighters:
		if f.gauge >= MAX and not was_full[f.id]:
			out.append({"type": "gauge_full", "fighter": f.id, "character": f.character, "pos": f.pos})
	return out


static func _gain_from(e: Dictionary, fighters: Array[Fighter], config: GameConfig) -> void:
	var type := String(e["type"])
	if type == "gimmick_damage":
		_add(fighters, int(e["target"]), float(e.get("amount", 0.0)) * config.special_gauge_per_damage_taken)
		return
	if type != "hit" and type != "guard_hit":
		return
	var dealt := float(e.get("damage", 0.0))
	var attacker := int(e["attacker"])
	var target := int(e["target"])
	_add(fighters, target, dealt * config.special_gauge_per_damage_taken)
	if attacker != target and int(e.get("attack_kind", -1)) != AttackSet.Kind.SPECIAL:
		_add(fighters, attacker, dealt * config.special_gauge_per_damage_dealt)


static func _add(fighters: Array[Fighter], id: int, amount: float) -> void:
	if id < 0 or id >= fighters.size() or amount <= 0.0:
		return
	var f := fighters[id]
	if f.is_alive():
		f.gauge = minf(f.gauge + amount, MAX)
