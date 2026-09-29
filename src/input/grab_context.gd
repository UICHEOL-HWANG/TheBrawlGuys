class_name GrabContext
extends RefCounted
## What the grab button would do right now for one fighter (PRD §3.3, DS-CMP-04 highlight):
## throw the carried item or held fighter, pick up an item, grab a fighter in reach, or nothing.
## Reads state_view() values only and mirrors ItemActions / Grab closely enough for a hint.

enum Kind { NONE, THROW, ITEM, FIGHTER }


static func evaluate(view: Dictionary, self_id: int, config: GameConfig) -> Dictionary:
	var me := _fighter(view, self_id)
	if me.is_empty():
		return _none()
	var state := int(me["state"])
	var pos: Vector3 = me["pos"]
	if int(me["hitstop_ticks"]) > 0:
		return _none()  # the sim swallows presses during hitstop
	if state == Fighter.State.HOLDING:
		return {"kind": Kind.THROW, "pos": pos}
	if state != Fighter.State.IDLE and state != Fighter.State.MOVE and state != Fighter.State.AIR:
		return _none()
	if int(me["item_kind"]) != Fighter.NONE:
		return {"kind": Kind.THROW, "pos": pos}
	if not bool(me["on_ground"]):
		return _none()
	var item := _nearest_item(view, pos, config.item_pickup_radius)
	if not item.is_empty():
		return {"kind": Kind.ITEM, "pos": item["pos"]}
	var foe := _foe_in_box(view, self_id, me, config)
	if not foe.is_empty():
		return {"kind": Kind.FIGHTER, "pos": foe["pos"]}
	return _none()


static func _none() -> Dictionary:
	return {"kind": Kind.NONE, "pos": Vector3.ZERO}


static func _fighter(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _nearest_item(view: Dictionary, pos: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for it: Dictionary in view.get("items", []):
		if int(it["state"]) != Item.State.GROUND or int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var d := _flat(it["pos"], pos)
		if d <= best_d:
			best = it
			best_d = d
	return best


## First fighter the sim grab box would connect with: the box sits grab_forward in front of the
## grabber (mirrors AttackSet._grab and Combat.hitbox_center).
static func _foe_in_box(view: Dictionary, self_id: int, me: Dictionary, config: GameConfig) -> Dictionary:
	var pos: Vector3 = me["pos"]
	var facing: Vector3 = me["facing"]
	var half_height := config.fighter_height * 0.5
	var center := pos + facing * config.grab_forward + Vector3.UP * half_height
	var half := Vector3(config.grab_half_width, half_height, config.grab_half_width)
	var yaw := Collision.yaw_of(facing)
	for f: Dictionary in view["fighters"]:
		var s := int(f["state"])
		if int(f["id"]) == self_id or s == Fighter.State.KO or s == Fighter.State.HELD or s == Fighter.State.HOLDING:
			continue
		if int(f["invuln_ticks"]) > 0:
			continue
		if Collision.capsule_hits_box(f["pos"], config.fighter_radius, config.fighter_height, center, yaw, half):
			return f
	return {}
