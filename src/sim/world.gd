class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.
## Tick order: ItemActions.pre_step -> Motion.step per fighter -> separate -> Grab.step -> Grab.resolve -> Combat.resolve -> ItemMotion.step -> GimmickRunner.step -> ItemField.spawn_step -> Rules.apply -> Grab.cleanup -> ItemActions.drop_from_disabled -> winner.
## The config is a tracked sim input: its fingerprint is part of every snapshot (context D1). Snapshot v3 adds the Phase 2 fighter fields. Snapshot v4 adds the item field.
## Snapshot v5 adds the arena state (broken floors, gimmick state) and the fighter burn fields (Phase 4).

const SNAPSHOT_VERSION := 5
const DEFAULT_PLAYER_COUNT := 2
const SNAPSHOT_TYPES := {
	"tick": TYPE_INT, "rng_seed": TYPE_INT, "rng_state": TYPE_INT, "config_fp": TYPE_INT,
	"match_over": TYPE_BOOL, "winner": TYPE_INT, "fighters": TYPE_ARRAY,
	"items": TYPE_DICTIONARY, "arena": TYPE_DICTIONARY,
}

var config: GameConfig
## This World's own arena (a copy of the one passed in): floors, ring-out rules and gimmicks.
var arena: ArenaData
var tick_count: int = 0
var fighters: Array[Fighter] = []
var items: ItemField = ItemField.new()
var match_over: bool = false
var winner_id: int = Rules.ONGOING
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Events produced by the most recent tick (plain data, e.g. hits and ring-outs).
var _events: Array[Dictionary] = []


## p_arena defaults to the classic circle (ArenaCatalog.default), the Phase 1-3 arena.
func _init(p_config: GameConfig, p_seed: int = 0, p_player_count: int = DEFAULT_PLAYER_COUNT,
		p_arena: ArenaData = null) -> void:
	config = p_config
	arena = p_arena.copy() if p_arena != null else ArenaCatalog.default(config)
	arena.start(config)
	_rng.seed = p_seed
	for i: int in p_player_count:
		fighters.append(Rules.spawn_fighter(i, p_player_count, config, arena))


func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		arena.sync(config)
		var attacks := AttackSet.from_config(config)
		var frame := _resolve_inputs(inputs)
		_events.append_array(ItemActions.pre_step(fighters, frame, items, config))
		for f: Fighter in fighters:
			Motion.step(f, frame[f.id], config, attacks, arena)
		Motion.separate(fighters, config)
		_events.append_array(Grab.step(fighters, frame, attacks, config))
		_events.append_array(Grab.resolve(fighters, attacks, config))
		_events.append_array(Combat.resolve(fighters, attacks, config))
		_events.append_array(ItemMotion.step(items, fighters, attacks, config, arena))
		_events.append_array(GimmickRunner.step(arena, fighters, config, tick_count, _events))
		_events.append_array(items.spawn_step(tick_count, _rng, config, arena.item_area))
		_events.append_array(Rules.apply(fighters, config, arena))
		Grab.cleanup(fighters)
		_events.append_array(ItemActions.drop_from_disabled(fighters, items, config))
		var result := Rules.winner(fighters)
		if result != Rules.ONGOING:
			match_over = true
			winner_id = result
	tick_count += 1


## One input per fighter id (copies, so later steps may clear consumed buttons without touching
## the caller's frames); missing entries are neutral.
func _resolve_inputs(inputs: Array[InputFrame]) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for f: Fighter in fighters:
		out.append(inputs[f.id].copy() if f.id < inputs.size() else InputFrame.neutral())
	return out


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Plain value data only (ints/floats/Vector types/Arrays and Dictionaries of the same):
## never references to live sim objects, so the render layer can keep prev/curr copies
## that stay valid after later ticks. "arena" is the ArenaCatalog id (render rebuilds the
## geometry from it), "arena_floors" the floors still standing, "gimmicks" each gimmick's state.
func state_view() -> Dictionary:
	var views: Array[Dictionary] = []
	for f: Fighter in fighters:
		views.append(f.to_view())
	return {
		"tick": tick_count,
		"arena": arena.id,
		"arena_theme": arena.theme_id,
		"arena_radius": arena.view_radius(),
		"arena_floors": arena.floor_active.duplicate(),
		"gimmicks": arena.gimmick_views(),
		"match_over": match_over,
		"winner": winner_id,
		"fighters": views,
		"items": items.views(),
		"events": _events.duplicate(true),
	}


func snapshot() -> PackedByteArray:
	var data: Array[Dictionary] = []
	for f: Fighter in fighters:
		data.append(f.to_data())
	return var_to_bytes({
		"v": SNAPSHOT_VERSION,
		"tick": tick_count,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"config_fp": config.fingerprint(),
		"match_over": match_over,
		"winner": winner_id,
		"fighters": data,
		"items": items.to_data(),
		"arena": arena.to_data(),
	})


func restore(data: PackedByteArray) -> bool:
	var s := _decode(data)
	if s.is_empty():
		return false
	var restored: Array[Fighter] = []
	for d: Variant in s["fighters"]:
		var f: Fighter = Fighter.from_data(d) if d is Dictionary else null
		if f == null:
			push_error("World.restore: invalid fighter data")
			return false
		restored.append(f)
	var restored_items := ItemField.from_data(s["items"])
	if restored_items == null:
		push_error("World.restore: invalid item data")
		return false
	var restored_arena := arena.copy()
	if not restored_arena.load_data(s["arena"]):
		push_error("World.restore: invalid arena data")
		return false
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	match_over = s["match_over"]
	winner_id = s["winner"]
	fighters = restored
	items = restored_items
	arena = restored_arena
	_events = []
	return true


## The snapshot dictionary when version, keys, config and arena match this World, else {}.
func _decode(data: PackedByteArray) -> Dictionary:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != SNAPSHOT_VERSION:
		push_error("World.restore: incompatible snapshot")
		return {}
	var s: Dictionary = decoded
	for key: String in SNAPSHOT_TYPES:
		if not s.has(key) or typeof(s[key]) != SNAPSHOT_TYPES[key]:
			push_error("World.restore: incomplete snapshot")
			return {}
	if s["config_fp"] != config.fingerprint():
		push_error("World.restore: config mismatch")
		return {}
	if (s["arena"] as Dictionary).get("id") != arena.id:
		push_error("World.restore: arena mismatch")
		return {}
	return s


func state_hash() -> int:
	return hash(snapshot())
