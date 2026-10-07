class_name ProjectileLayer
extends Node3D
## One ProjectileView per projectile id (combat-motion B1), interpolated prev -> curr like
## ItemLayer. A view is freed when its id leaves the view (the projectile hit or expired; the
## flash and blast come from CombatFxLayer's events).

var _views: Dictionary = {}


func sync(prev_list: Array, curr_list: Array, alpha: float) -> void:
	var prev_by_id := {}
	for p: Dictionary in prev_list:
		prev_by_id[int(p["id"])] = p
	var alive := {}
	for p: Dictionary in curr_list:
		var id := int(p["id"])
		alive[id] = true
		if _views.has(id) and (_views[id] as ProjectileView).kind() != int(p["kind"]):
			(_views[id] as ProjectileView).queue_free()  # a reused id from a restarted run
			_views.erase(id)
		if not _views.has(id):
			var v := ProjectileView.new()
			add_child(v)
			v.setup(int(p["kind"]), float(p["radius"]))
			_views[id] = v
		(_views[id] as ProjectileView).apply(prev_by_id.get(id, {}), p, alpha)
	for id: int in _views.keys():
		if not alive.has(id):
			(_views[id] as ProjectileView).queue_free()
			_views.erase(id)


## Frees every view (a new match starts a new projectile id sequence).
func clear() -> void:
	for id: int in _views.keys():
		(_views[id] as ProjectileView).queue_free()
	_views.clear()


func view_count() -> int:
	return _views.size()


func view(id: int) -> ProjectileView:
	return _views.get(id)
