class_name ViewEvents
extends RefCounted
## Presentation events read from one tick's view difference (context F8): landing (dust),
## respawn (light pillar) and fast launched motion (knockback trail). The sim emits nothing new.


static func detect(prev: Array, curr: Array, config: GameConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in mini(prev.size(), curr.size()):
		var a: Dictionary = prev[i]
		var b: Dictionary = curr[i]
		var id := int(b["id"])
		var pos: Vector3 = b["pos"]
		if int(a["spawn_id"]) != int(b["spawn_id"]):
			out.append({"type": "respawned", "id": id, "pos": pos})
			continue
		var from: Vector3 = a["pos"]
		if bool(a["on_ground"]) and not bool(b["on_ground"]) and pos.y > from.y:
			out.append({"type": "jumped", "id": id, "pos": pos})
		if not bool(a["on_ground"]) and bool(b["on_ground"]):
			var dust := dust_intensity((from.y - pos.y) / SimTime.TICK_DT, config)
			if dust > 0.0:
				out.append({"type": "landed", "id": id, "pos": pos, "intensity": dust})
		if int(b["state"]) == Fighter.State.HITSTUN:
			var trail := trail_intensity(from.distance_to(pos) / SimTime.TICK_DT, config)
			if trail > 0.0:
				out.append({"type": "trail", "id": id, "pos": pos, "intensity": trail})
	return out


static func trail_intensity(speed: float, config: GameConfig) -> float:
	return _ramp(speed, config.trail_speed_threshold, config.trail_speed_full)


static func dust_intensity(fall_speed: float, config: GameConfig) -> float:
	return _ramp(fall_speed, config.dust_min_fall_speed, config.dust_full_fall_speed)


static func _ramp(v: float, lo: float, hi: float) -> float:
	if v < lo:
		return 0.0
	if hi <= lo:
		return 1.0
	return clampf((v - lo) / (hi - lo), 0.0, 1.0)
