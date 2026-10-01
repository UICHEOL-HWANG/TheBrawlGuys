class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.
## The tick's step order lives in WorldStep, the snapshot format in WorldCodec (the config is a
## tracked sim input: its fingerprint is part of every snapshot, context D1).
## Phase 5: each slot plays a character (CharacterData id, "" = the classic fighter).
## Combat-depth D: the match plays under MatchRules (stock / team / timed); mode_state tracks
## scores, the clock and the winning team, and ModeOutcome decides the winner.

const SNAPSHOT_VERSION := WorldCodec.VERSION
const DEFAULT_PLAYER_COUNT := 2

var config: GameConfig
## This World's own arena (a copy of the one passed in): floors, ring-out rules and gimmicks.
var arena: ArenaData
var tick_count: int = 0
var fighters: Array[Fighter] = []
var items: ItemField = ItemField.new()
var projectiles: ProjectileField = ProjectileField.new()
var match_over: bool = false
var winner_id: int = Rules.ONGOING
var mode_state: ModeState
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Events produced by the most recent tick (plain data, e.g. hits and ring-outs).
var _events: Array[Dictionary] = []


## p_arena defaults to the classic circle (ArenaCatalog.default), the Phase 1-3 arena.
## p_characters[i] is slot i's character (CharacterData.resolve); missing entries are classic.
## p_rules defaults to stock (MatchRules.stock).
func _init(p_config: GameConfig, p_seed: int = 0, p_player_count: int = DEFAULT_PLAYER_COUNT,
		p_arena: ArenaData = null, p_characters: Array[String] = [], p_rules: MatchRules = null) -> void:
	config = p_config
	arena = p_arena.copy() if p_arena != null else ArenaCatalog.default(config)
	arena.start(config)
	_rng.seed = p_seed
	mode_state = ModeState.new(p_rules, p_player_count)
	for i: int in p_player_count:
		var f := Rules.spawn_fighter(i, p_player_count, config, arena)
		f.character = CharacterData.resolve(p_characters[i] if i < p_characters.size() else CharacterData.DEFAULT)
		f.ally_mask = mode_state.rules.ally_mask(i)
		fighters.append(f)


func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		_events = WorldStep.run(self, _resolve_inputs(inputs), _rng)
		_events.append_array(mode_state.observe(_events, tick_count, SimTime.to_ticks(config.ringout_credit_time)))
		var result := ModeOutcome.resolve(fighters, mode_state, _events)
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
## geometry from it), "arena_floors" the floors still standing, "gimmicks" each gimmick's state,
## "projectiles" every projectile in flight (Projectile.to_view), "mode" the ModeState view (rule,
## teams, scores, ticks_left, sudden_death, winner_team).
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
		"projectiles": projectiles.views(),
		"mode": mode_state.view(),
		"events": _events.duplicate(true),
	}


func snapshot() -> PackedByteArray:
	return WorldCodec.encode(self, _rng)


func restore(data: PackedByteArray) -> bool:
	var r := WorldCodec.decode(self, data)
	if r.is_empty():
		return false
	var s: Dictionary = r["s"]
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	match_over = s["match_over"]
	winner_id = s["winner"]
	fighters.assign(r["fighters"])
	items = r["items"]
	arena = r["arena"]
	projectiles = r["projectiles"]
	mode_state = r["mode"]
	_events = []
	return true


func state_hash() -> int:
	return hash(snapshot())
