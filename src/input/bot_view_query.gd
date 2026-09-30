class_name BotViewQuery
extends RefCounted
## Read-only lookups a bot makes in a state_view (split out of BotController, unchanged logic).


static func find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func flat(from: Vector3, to: Vector3) -> Vector2:
	return Vector2(to.x - from.x, to.z - from.z)


static func nearest_foe(view: Dictionary, self_id: int, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var d := flat(my_pos, f["pos"]).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best


## Nearest lit-free item on the ground, or still falling (it lands straight below at pos.x, pos.z)
## as long as that landing spot is safe ground (not near an edge or over a gap).
static func nearest_item(view: Dictionary, my_pos: Vector3, arena: ArenaData, config: GameConfig) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := config.bot_item_seek_range
	for it: Dictionary in view.get("items", []):
		var state := int(it["state"])
		if state != Item.State.GROUND and state != Item.State.FALLING:
			continue
		if int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var landing: Vector3 = it["pos"]
		if state == Item.State.FALLING and not is_safe(arena, Vector3(landing.x, 0.0, landing.z), config):
			continue
		var d := flat(my_pos, it["pos"]).length()
		if d <= best_dist:
			best_dist = d
			best = it
	return best


## True when the foe stands within `reach` of the item too: both pressing grab there hands the
## item to the lower id and turns the other press into a grab attack on it.
static func contested(item: Dictionary, foe: Dictionary, reach: float) -> bool:
	return not foe.is_empty() and flat(foe["pos"], item["pos"]).length() <= reach


static func is_safe(arena: ArenaData, pos: Vector3, config: GameConfig) -> bool:
	return ArenaFloor.over_floor(arena, pos) and ArenaFloor.safe_point(arena, pos, config.bot_edge_ratio) == pos
