class_name SpatialFeatures
extends RefCounted
## Per-slot spatial habits (platform A8, analytics-strategy §3.2) from each tick's fighter views,
## counting only living (non-KO) ticks: distance travelled within one life, mean distance to the
## nearest living opponent, share of time past EDGE_RATIO of the arena radius, share of time in
## the air, and ticks holding each item kind.

const EDGE_RATIO := 0.8
const NO_ITEM := -1
const DISTANCE_STEP := 0.01
const RATIO_STEP := 0.001

var _slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		_slots.append({"alive": 0, "air": 0, "edge": 0, "dist": 0.0, "near_sum": 0.0, "near_n": 0, "items": {}})


## prev: last tick's fighter views (same order), fighters: this tick's.
func observe(prev: Array, fighters: Array, arena_radius: float) -> void:
	for i: int in fighters.size():
		var f: Dictionary = fighters[i]
		var slot := int(f["id"])
		if int(f["state"]) == Fighter.State.KO or slot < 0 or slot >= _slots.size():
			continue
		var s := _slots[slot]
		var pos: Vector3 = f["pos"]
		s["alive"] = int(s["alive"]) + 1
		if not bool(f.get("on_ground", true)):
			s["air"] = int(s["air"]) + 1
		if Vector2(pos.x, pos.z).length() > EDGE_RATIO * arena_radius:
			s["edge"] = int(s["edge"]) + 1
		if i < prev.size() and int(prev[i]["spawn_id"]) == int(f["spawn_id"]):
			s["dist"] = float(s["dist"]) + pos.distance_to(prev[i]["pos"] as Vector3)
		var near := _nearest(f, fighters)
		if near >= 0.0:
			s["near_sum"] = float(s["near_sum"]) + near
			s["near_n"] = int(s["near_n"]) + 1
		_hold_item(s, int(f.get("item_kind", NO_ITEM)))


func summary(slot: int) -> Dictionary:
	var s := _slots[slot]
	var alive := maxi(int(s["alive"]), 1)
	var near_n := int(s["near_n"])
	return {
		"distance_travelled": snappedf(float(s["dist"]), DISTANCE_STEP),
		"avg_nearest_opponent_dist": snappedf(float(s["near_sum"]) / near_n, DISTANCE_STEP) if near_n > 0 else null,
		"edge_time_ratio": snappedf(float(s["edge"]) / alive, RATIO_STEP),
		"air_time_ratio": snappedf(float(s["air"]) / alive, RATIO_STEP),
		"item_hold_ticks": (s["items"] as Dictionary).duplicate(),
	}


func _hold_item(s: Dictionary, kind: int) -> void:
	if kind == NO_ITEM:
		return
	var items: Dictionary = s["items"]
	var name := ItemTelemetry.item_name(kind)
	items[name] = int(items.get(name, 0)) + 1


## Distance to the nearest living other fighter, or -1 when none is alive.
static func _nearest(f: Dictionary, fighters: Array) -> float:
	var best := -1.0
	var pos: Vector3 = f["pos"]
	for o: Dictionary in fighters:
		if int(o["id"]) == int(f["id"]) or int(o["state"]) == Fighter.State.KO:
			continue
		var d := pos.distance_to(o["pos"] as Vector3)
		if best < 0.0 or d < best:
			best = d
	return best
