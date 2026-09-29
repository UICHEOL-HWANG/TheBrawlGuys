class_name ItemLayer
extends Node3D
## One ItemView per item id, interpolated prev -> curr like fighters. A new id (a fresh box, or a
## thrown item that was picked up) gets a new view, so nothing slides across the map.

var _config: GameConfig
var _views: Dictionary = {}


func setup(config: GameConfig) -> void:
	_config = config


func sync(prev_items: Array, curr_items: Array, alpha: float, tick: int) -> void:
	var prev_by_id := {}
	for it: Dictionary in prev_items:
		prev_by_id[int(it["id"])] = it
	var alive := {}
	for it: Dictionary in curr_items:
		var id := int(it["id"])
		alive[id] = true
		if not _views.has(id):
			var v := ItemView.new()
			add_child(v)
			v.setup(int(it["kind"]), _config)
			_views[id] = v
		(_views[id] as ItemView).apply(prev_by_id.get(id, {}), it, alpha, tick)
	for id: int in _views.keys():
		if not alive.has(id):
			(_views[id] as ItemView).queue_free()
			_views.erase(id)


func view_count() -> int:
	return _views.size()


func view(id: int) -> ItemView:
	return _views.get(id)
