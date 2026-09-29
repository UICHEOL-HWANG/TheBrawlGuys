class_name Item
extends RefCounted
## One loose item (PRD §4.4, context E6): a box falling from the sky, lying on the ground, or
## flying after a throw. Picking an item up removes it from the field; the fighter then carries
## its kind and uses (Fighter.item_kind / item_uses) until it throws, drops or loses it.

enum Kind { BAT, BOMB, ROCK }
enum State { FALLING, GROUND, THROWN }

const KIND_COUNT := 3
const UNLIT := -1
const DATA_TYPES := {
	"id": TYPE_INT, "kind": TYPE_INT, "state": TYPE_INT, "pos": TYPE_VECTOR3, "vel": TYPE_VECTOR3,
	"uses": TYPE_INT, "fuse_ticks": TYPE_INT, "owner_id": TYPE_INT,
}

var id: int = 0
var kind: int = Kind.BAT
var state: int = State.FALLING
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
## Swings left (bats).
var uses: int = 0
## Ticks until a lit bomb explodes, or UNLIT.
var fuse_ticks: int = UNLIT
## The fighter who threw it (its own projectile never hits it), or Fighter.NONE.
var owner_id: int = Fighter.NONE


func is_pickable() -> bool:
	return state == State.GROUND and fuse_ticks == UNLIT


func to_view() -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "pos": pos, "uses": uses, "fuse_ticks": fuse_ticks}


func to_data() -> Dictionary:
	var d := {}
	for key: String in DATA_TYPES:
		d[key] = get(key)
	return d


static func from_data(d: Dictionary) -> Item:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	var it := Item.new()
	for key: String in DATA_TYPES:
		it.set(key, d[key])
	return it
