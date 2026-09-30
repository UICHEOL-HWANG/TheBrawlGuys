class_name Projectile
extends RefCounted
## One flying projectile (PRD-STYLE-03): ranged bolts and the Mage's big fireball. It flies
## straight (no gravity) for ticks_left ticks, hits the first fighter capsule it touches (never
## its owner) and uses its owner's attack `attack_kind` for the hit. Guard blocks it (Combat).

enum Kind { BOLT, HEAVY_BOLT, FIREBALL }

const KIND_NAMES: Array[String] = ["bolt", "heavy_bolt", "fireball"]
const DATA_TYPES := {
	"id": TYPE_INT, "owner_id": TYPE_INT, "kind": TYPE_INT, "attack_kind": TYPE_INT, "pos": TYPE_VECTOR3,
	"vel": TYPE_VECTOR3, "ticks_left": TYPE_INT, "radius": TYPE_FLOAT, "power": TYPE_FLOAT,
}

var id: int = 0
var owner_id: int = Fighter.NONE
var kind: int = Kind.BOLT
## AttackSet.Kind in the owner's table whose numbers the hit uses.
var attack_kind: int = AttackSet.Kind.LIGHT_1
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var ticks_left: int = 0
var radius: float = 0.0
## Damage and knockback multiplier (heavy charge).
var power: float = 1.0


func to_view() -> Dictionary:
	return {
		"id": id, "owner": owner_id, "kind": kind, "pos": pos, "vel": vel, "radius": radius,
		"ticks_left": ticks_left,
	}


## The payload shared by projectile_spawn / projectile_hit / projectile_expire events.
func event(type: String) -> Dictionary:
	return {"type": type, "id": id, "owner": owner_id, "kind": kind, "pos": pos}


func to_data() -> Dictionary:
	var d := {}
	for key: String in DATA_TYPES:
		d[key] = get(key)
	return d


static func from_data(d: Dictionary) -> Projectile:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	var p := Projectile.new()
	for key: String in DATA_TYPES:
		p.set(key, d[key])
	return p
