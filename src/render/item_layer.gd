class_name ItemLayer
extends Node3D
## One ItemView per item id, interpolated prev -> curr like fighters. A new id (a fresh box, or a
## thrown item that was picked up) gets a new view, so nothing slides across the map.

## A falling item this far below the drop height is a dropped item, not a fresh box.
const BOX_HEIGHT_TOLERANCE := 0.5

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
			var p: Vector3 = it["pos"]
			var boxed := int(it["state"]) == Item.State.FALLING and p.y >= _config.item_drop_height - BOX_HEIGHT_TOLERANCE
			v.setup(int(it["kind"]), _config, boxed)
			_views[id] = v
		(_views[id] as ItemView).apply(prev_by_id.get(id, {}), it, alpha, tick)
	for id: int in _views.keys():
		if not alive.has(id):
			(_views[id] as ItemView).queue_free()
			_views.erase(id)


## Frees every view (a new match starts with a new item id sequence).
func clear() -> void:
	for id: int in _views.keys():
		(_views[id] as ItemView).queue_free()
	_views.clear()


func view_count() -> int:
	return _views.size()


func view(id: int) -> ItemView:
	return _views.get(id)
