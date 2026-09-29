class_name BotController
extends RefCounted
## Phase 1 bot (PRD §6.4, step 1): approach, attack in range, retreat from the edge, jump back
## when falling off. Reads only World.state_view() values and produces InputFrames — never
## touches the sim directly. Deterministic (no randomness).

var _self_id: int
var _config: GameConfig
var _cooldown: int = 0


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


func sample(view: Dictionary) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
	var me := _find(view, _self_id)
	if me.is_empty() or int(me["state"]) == Fighter.State.KO:
		return InputFrame.neutral()
	var my_pos: Vector3 = me["pos"]
	var flat := Vector2(my_pos.x, my_pos.z)
	var radius: float = view["arena_radius"]
	var to_center := -flat.normalized() if flat.length() > 0.001 else Vector2.ZERO

	if not bool(me["on_ground"]) and flat.length() > radius and my_pos.y < 0.0:
		return InputFrame.make(to_center.x, to_center.y, int(me["jumps_left"]) > 0)
	if flat.length() > radius * _config.bot_edge_ratio:
		return InputFrame.make(to_center.x, to_center.y)

	var foe := _nearest_foe(view, my_pos)
	if foe.is_empty():
		return InputFrame.neutral()
	var foe_pos: Vector3 = foe["pos"]
	var delta := Vector2(foe_pos.x - my_pos.x, foe_pos.z - my_pos.z)
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_attack_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, true)
	return InputFrame.make(dir.x, dir.y)


static func _find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


func _nearest_foe(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == _self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var p: Vector3 = f["pos"]
		var d := Vector2(p.x - my_pos.x, p.z - my_pos.z).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best
