class_name MatchStage
extends Node3D
## The world a match is drawn in (platform B1/B2, Phase 4 T6): the sun and sky in the arena's
## theme (DS-THM-02), the arena with its gimmick views, the decor around it, one FighterView plus
## its FighterHazards (burning, fog silhouette) and DefenseFx (dodges, guard meter) per slot and the item layer, drawn from
## interpolated sim views. Shared by the match scene and the menu backdrop so both look the same;
## cameras, HUD, feel and sound stay with their owners.

signal arena_changed(arena_id: String)

var _config: GameConfig
var _env: EnvironmentRig
var _arena_view: ArenaView
var _decor: DecorView
var _decor_seed: int = 0
## The id last asked for (an unknown id resolves to the default arena, so compare requests).
var _requested_id: String = ""
var _views: Array[FighterView] = []
var _hazards: Array[FighterHazards] = []
var _defense: Array[DefenseFx] = []
var _reactions: Array[HitReaction] = []
var _items: ItemLayer


## characters[i]: slot i's CharacterData id, which picks its model ("" / missing = slot model).
func setup(config: GameConfig, decor_seed: int, player_count: int,
		arena_id: String = ArenaCatalog.DEFAULT_ID, characters: Array[String] = []) -> void:
	_config = config
	_decor_seed = decor_seed
	_env = EnvironmentRig.new()
	add_child(_env)
	_env.setup()
	_build_arena(arena_id)
	for i: int in player_count:
		var view := FighterView.new()
		add_child(view)
		view.setup(i, config, characters[i] if i < characters.size() else CharacterData.DEFAULT)
		_views.append(view)
		var fx := DefenseFx.new()
		view.add_child(fx)
		fx.setup(i, config, view)
		_defense.append(fx)
		var reaction := HitReaction.new()
		view.add_child(reaction)
		reaction.setup(view.model())
		_reactions.append(reaction)
		var hazards := FighterHazards.new()
		add_child(hazards)
		hazards.setup(i, config)
		_hazards.append(hazards)
	_items = ItemLayer.new()
	add_child(_items)
	_items.setup(config)
	apply_quality()
	config.changed.connect(apply_quality)


## Swaps in another arena (menu backdrop cycling): arena view, decor and theme. A no-op while
## the requested id stays the same (called every frame by the backdrop).
func set_arena(arena_id: String) -> void:
	if arena_id == _requested_id:
		return
	for old: Node in [_arena_view, _decor]:
		remove_child(old)
		old.queue_free()
	_build_arena(arena_id)
	arena_changed.emit(arena_id)


func apply_quality() -> void:
	var level := Quality.resolve(_config.quality_level, Quality.platform())
	_env.apply_quality(level)
	var blobs := bool(Quality.settings(level)["blob_shadows"])
	for v: FighterView in _views:
		v.set_blob_shadow(blobs)


## Fighters, items and the arena between the previous and current tick (render interpolation).
func draw(prev: Dictionary, curr: Dictionary, alpha: float, delta: float) -> void:
	var before_all: Array = prev["fighters"]
	var now_all: Array = curr["fighters"]
	var tick := int(curr["tick"])
	_arena_view.sync(curr, tick, delta)
	var fog := _arena_view.fog_amount()
	_env.set_fog_boost(fog)
	for i: int in mini(_views.size(), now_all.size()):
		var before: Dictionary = before_all[i] if i < before_all.size() else {}
		_views[i].apply(before, now_all[i], alpha, tick)
		_views[i].animate(now_all[i], delta)
		_defense[i].apply(now_all[i], delta)
		_hazards[i].apply(now_all[i], _views[i].position, fog)
	_items.sync(prev["items"], curr["items"], alpha, tick)


## This frame's sim events: guard wobbles, hit reactions (DS-VFX-08), perfect-guard rings and
## arena reactions (mushroom squash).
func on_events(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"guard_hit":
				var id := int(e["target"])
				if id < _views.size():
					_views[id].wobble()
			"hit":
				_react(e)
			"perfect_guard", "tech":  # a tech flashes the same white ring (DS-VFX-14)
				if int(e["fighter"]) < _defense.size():
					_defense[int(e["fighter"])].perfect_flash()
	_arena_view.on_events(events)


func reactions() -> Array[HitReaction]:
	return _reactions


## Victim flash and jolt; a melee attacker also lunges (render only).
func _react(e: Dictionary) -> void:
	var target := int(e["target"])
	var attacker := int(e["attacker"])
	if target < 0 or target >= _views.size():
		return
	var melee := e.has("attack_kind") and attacker >= 0 and attacker < _views.size()
	var at: Vector3 = e["pos"]
	var from := _views[attacker].position if melee else at
	var dir := ImpactTier.hit_direction(_views[target].position, at, from, melee)
	var hold := float(e["hitstop_ticks"]) / SimTime.TICK_RATE
	_reactions[target].struck(dir, ImpactTier.of(float(e["knockback"]), _config), hold)
	if melee and attacker != target:
		_reactions[attacker].strike(dir, hold)


func set_identity_visible(on: bool) -> void:
	for v: FighterView in _views:
		v.set_identity_visible(on)
	for h: FighterHazards in _hazards:
		h.set_identity_visible(on)


func views() -> Array[FighterView]:
	return _views


func hazards() -> Array[FighterHazards]:
	return _hazards


func clear_items() -> void:
	_items.clear()


func item_layer() -> ItemLayer:
	return _items


func environment_rig() -> EnvironmentRig:
	return _env


func arena_view() -> ArenaView:
	return _arena_view


func decor() -> DecorView:
	return _decor


func _build_arena(arena_id: String) -> void:
	_requested_id = arena_id
	_arena_view = ArenaView.new()
	add_child(_arena_view)
	_arena_view.setup(_config, arena_id)
	_env.apply_theme(_arena_view.theme())
	_decor = DecorView.new()
	add_child(_decor)
	_decor.setup(_config, _decor_seed, _arena_view.arena().copy(), _arena_view.theme())
