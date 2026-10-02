class_name ItemField
extends RefCounted
## Loose items plus the box spawner (PRD §4.4, context E6/E8). The spawner is the only user of
## the World RNG and always draws in the same order: next spawn tick, angle, radius, kind. When
## the field is full the drop is skipped but the next one is still scheduled. The kind is one draw
## over the classic three or, with item_pool_extended, all six (PRD-ITEM-05..07).

const NOT_SCHEDULED := -1

var items: Array[Item] = []
var next_spawn_tick: int = NOT_SCHEDULED
var next_id: int = 0


## Boxes drop into `area` (the arena's item_area) at item_spawn_radius_ratio of its size.
func spawn_step(tick: int, rng: RandomNumberGenerator, config: GameConfig, area: ArenaShape) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if next_spawn_tick == NOT_SCHEDULED:
		next_spawn_tick = tick + _interval(rng, config)
		return events
	if tick < next_spawn_tick:
		return events
	next_spawn_tick = tick + _interval(rng, config)
	if _loose_count() >= config.item_max_on_field:
		return events
	var u1 := rng.randf()
	var u2 := rng.randf()
	var pool := Item.KIND_COUNT if config.item_pool_extended else Item.CLASSIC_KIND_COUNT
	var kind := rng.randi_range(0, pool - 1)
	var at := area.sample_point(u1, u2, config.item_spawn_radius_ratio, config.item_drop_height)
	var it := add(kind, at, Item.State.FALLING, config)
	events.append({"type": "item_spawn", "id": it.id, "kind": kind, "pos": it.pos})
	return events


func add(kind: int, pos: Vector3, state: int, config: GameConfig) -> Item:
	var it := Item.new()
	it.id = next_id
	next_id += 1
	it.kind = kind
	it.state = state
	it.pos = pos
	it.uses = Item.uses_for(kind, config)
	items.append(it)
	return it


## Items that count toward item_max_on_field: everything but laid banana traps (they wait for a
## foot, so they must not stop the drops).
func _loose_count() -> int:
	var n := 0
	for it: Item in items:
		if not it.is_trap():
			n += 1
	return n


func remove(it: Item) -> void:
	items.erase(it)


func views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Item in items:
		out.append(it.to_view())
	return out


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for it: Item in items:
		list.append(it.to_data())
	return {"items": list, "next_spawn_tick": next_spawn_tick, "next_id": next_id}


static func from_data(d: Dictionary) -> ItemField:
	if typeof(d.get("items")) != TYPE_ARRAY or typeof(d.get("next_spawn_tick")) != TYPE_INT \
			or typeof(d.get("next_id")) != TYPE_INT:
		return null
	var field := ItemField.new()
	for raw: Variant in d["items"]:
		var it: Item = Item.from_data(raw) if raw is Dictionary else null
		if it == null:
			return null
		field.items.append(it)
	field.next_spawn_tick = d["next_spawn_tick"]
	field.next_id = d["next_id"]
	return field


static func _interval(rng: RandomNumberGenerator, config: GameConfig) -> int:
	var lo := SimTime.to_ticks(config.item_spawn_min_time)
	return rng.randi_range(lo, maxi(SimTime.to_ticks(config.item_spawn_max_time), lo))
