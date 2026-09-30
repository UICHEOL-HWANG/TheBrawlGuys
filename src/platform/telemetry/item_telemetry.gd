class_name ItemTelemetry
extends RefCounted
## Item moments for Amplitude (platform A6): item_picked_up, item_used (swing / throw / explode)
## and item_hit. Remembers who last held each item so an explosion is credited to its thrower.
## emit(name, props) sends; count(slot, counter) updates SlotStats.

const ITEM_ATTACKS: Dictionary = {
	AttackSet.Kind.BAT: Item.Kind.BAT, AttackSet.Kind.ROCK: Item.Kind.ROCK, AttackSet.Kind.BOMB: Item.Kind.BOMB,
}

var _owner: Dictionary = {}  # item id -> fighter slot


func on_event(e: Dictionary, emit: Callable, count: Callable) -> void:
	match String(e["type"]):
		"item_pickup":
			_owner[int(e["id"])] = int(e["fighter"])
			emit.call("item_picked_up", {"slot": int(e["fighter"]), "item": item_name(int(e["kind"]))})
		"item_throw":
			_owner[int(e["id"])] = int(e["fighter"])
			count.call(int(e["fighter"]), "items_used")
			emit.call("item_used", {"slot": int(e["fighter"]), "item": item_name(int(e["kind"])), "action": "throw"})
		"explosion":
			var owner := int(_owner.get(int(e["id"]), -1))
			if owner >= 0:
				emit.call("item_used", {"slot": owner, "item": item_name(Item.Kind.BOMB), "action": "explode"})
		"hit", "guard_hit":
			var kind := int(e.get("attack_kind", -1))
			if ITEM_ATTACKS.has(kind):
				var item := int(e.get("item_kind", ITEM_ATTACKS[kind]))
				emit.call("item_hit", {"slot": int(e["attacker"]), "target_slot": int(e["target"]),
					"item": item_name(item), "guarded": e["type"] == "guard_hit"})


## A bat swing is an item use (the sim spends one bat use per swing).
func on_swing(slot: int, attack_kind: int, emit: Callable, count: Callable) -> void:
	if attack_kind == AttackSet.Kind.BAT:
		count.call(slot, "items_used")
		emit.call("item_used", {"slot": slot, "item": item_name(Item.Kind.BAT), "action": "swing"})


static func item_name(kind: int) -> String:
	var names := Item.Kind.keys()
	return String(names[kind]).to_lower() if kind >= 0 and kind < names.size() else "unknown"
