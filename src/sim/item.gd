class_name Item
extends RefCounted
## One loose item (PRD §4.4, context E6): a box falling from the sky, lying on the ground, or
## flying after a throw. Picking an item up removes it from the field; the fighter then carries
## its kind and uses (Fighter.item_kind / item_uses) until it throws, drops or loses it.
## HAMMER, GLOVE and BANANA (PRD-ITEM-05..07) are appended so classic kind values never move; they
## only drop with item_pool_extended. A thrown banana lies as a trap (is_trap): its fuse_ticks
## counts the thrower's grace down to 0 and stays there while the trap is live.

enum Kind { BAT, BOMB, ROCK, HAMMER, GLOVE, BANANA }
enum State { FALLING, GROUND, THROWN }

## Kinds the classic pool draws from (BAT, BOMB, ROCK).
const CLASSIC_KIND_COUNT := 3
const KIND_COUNT := 6
## Items swung with light (each use spends one of `uses`) and the attack each swing is.
const MELEE_ATTACKS := {Kind.BAT: AttackSet.Kind.BAT, Kind.HAMMER: AttackSet.Kind.HAMMER, Kind.GLOVE: AttackSet.Kind.GLOVE}
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
## Swings left (melee items).
var uses: int = 0
## Ticks until a lit bomb explodes, or a laid banana's thrower grace (0 = live trap), or UNLIT.
var fuse_ticks: int = UNLIT
## The fighter who threw it (its own projectile never hits it), or Fighter.NONE.
var owner_id: int = Fighter.NONE


func is_pickable() -> bool:
	return state == State.GROUND and fuse_ticks == UNLIT


## A banana lying where it was thrown: never picked up, slips whoever steps on it (ItemTraps).
func is_trap() -> bool:
	return kind == Kind.BANANA and state == State.GROUND and fuse_ticks != UNLIT


static func is_melee(item_kind: int) -> bool:
	return MELEE_ATTACKS.has(item_kind)


## Uses a fresh item of this kind starts with (swings for melee items, 1 otherwise).
static func uses_for(item_kind: int, config: GameConfig) -> int:
	match item_kind:
		Kind.BAT:
			return config.bat_uses
		Kind.HAMMER:
			return config.hammer_uses
		Kind.GLOVE:
			return config.glove_uses
	return 1


func to_view() -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "pos": pos, "uses": uses, "fuse_ticks": fuse_ticks,
		"trap": is_trap()}


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
