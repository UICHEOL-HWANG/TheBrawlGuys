class_name MatchStage
extends Node3D
## The world a match is drawn in (platform B1/B2): sun and sky, arena, decor, one FighterView per
## slot and the item layer, drawn from interpolated sim views. Shared by the match scene and the
## menu backdrop so both look the same; cameras, HUD, feel and sound stay with their owners.

var _config: GameConfig
var _env: EnvironmentRig
var _views: Array[FighterView] = []
var _items: ItemLayer


func setup(config: GameConfig, decor_seed: int, player_count: int) -> void:
	_config = config
	_env = EnvironmentRig.new()
	add_child(_env)
	_env.setup()
	var arena := ArenaView.new()
	add_child(arena)
	arena.setup(config)
	var decor := DecorView.new()
	add_child(decor)
	decor.setup(config, decor_seed)
	for i: int in player_count:
		var view := FighterView.new()
		add_child(view)
		view.setup(i, config)
		_views.append(view)
	_items = ItemLayer.new()
	add_child(_items)
	_items.setup(config)
	apply_quality()
	config.changed.connect(apply_quality)


func apply_quality() -> void:
	var level := Quality.resolve(_config.quality_level, Quality.platform())
	_env.apply_quality(level)
	var blobs := bool(Quality.settings(level)["blob_shadows"])
	for v: FighterView in _views:
		v.set_blob_shadow(blobs)


## Fighters and items between the previous and current tick (render interpolation contract).
func draw(prev: Dictionary, curr: Dictionary, alpha: float, delta: float) -> void:
	var before_all: Array = prev["fighters"]
	var now_all: Array = curr["fighters"]
	var tick := int(curr["tick"])
	for i: int in mini(_views.size(), now_all.size()):
		var before: Dictionary = before_all[i] if i < before_all.size() else {}
		_views[i].apply(before, now_all[i], alpha, tick)
		_views[i].animate(now_all[i], delta)
	_items.sync(prev["items"], curr["items"], alpha, tick)


func wobble_guards(events: Array) -> void:
	for e: Dictionary in events:
		if String(e["type"]) == "guard_hit":
			var id := int(e["target"])
			if id < _views.size():
				_views[id].wobble()


func clear_items() -> void:
	_items.clear()


func item_layer() -> ItemLayer:
	return _items


func environment_rig() -> EnvironmentRig:
	return _env
