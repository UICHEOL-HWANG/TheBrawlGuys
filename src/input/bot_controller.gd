class_name BotController
extends RefCounted
## Bot step 2 (PRD §6.4): step 1 (approach, attack in range, retreat from the edge, recover) plus
## guarding every other attack that starts in range (so it can still be hit), racing for nearby
## items, swinging bats, throwing rocks and bombs at range, mashing the light combo, grabbing a
## guarding foe and throwing held fighters away from the center. Reads only state_view() values
## and produces InputFrames — never touches the sim. Deterministic (no randomness).

## Pick up when the item is this deep inside the pickup radius (a margin against rounding).
const PICKUP_REACH_RATIO := 0.8

var _self_id: int
var _config: GameConfig
var _cooldown: int = 0
var _combo_left: int = 0
var _guard_left: int = 0
var _guard_next_threat: bool = true
var _foe_was_threat: bool = false


func _init(p_self_id: int, p_config: GameConfig) -> void:
	_self_id = p_self_id
	_config = p_config


## Light presses after the first swing so hits 2 and 3 land inside the combo buffer.
static func combo_mash_ticks(config: GameConfig) -> int:
	return 2 * (config.light_startup_ticks + config.light_active_ticks + config.light_recovery_ticks)


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
	if int(me["state"]) == Fighter.State.HOLDING:
		var out := -to_center if to_center != Vector2.ZERO else Vector2(1, 0)
		return InputFrame.make(out.x, out.y, false, false, false, false, true)
	if flat.length() > radius * _config.bot_edge_ratio:
		return InputFrame.make(to_center.x, to_center.y)

	var foe := _nearest_foe(view, my_pos)
	if _update_guard(foe, my_pos):
		return InputFrame.make(0, 0, false, false, false, true)
	if _combo_left > 0:
		_combo_left -= 1
		return InputFrame.make(0, 0, false, true)

	var item_kind := int(me.get("item_kind", Fighter.NONE))
	if item_kind == Item.Kind.BOMB or item_kind == Item.Kind.ROCK:
		return _use_throwable(foe, my_pos)
	if item_kind == Fighter.NONE:
		var it := _nearest_item(view, my_pos)
		if not it.is_empty():
			var to_item := _flat_delta(my_pos, it["pos"])
			if to_item.length() <= _config.item_pickup_radius * PICKUP_REACH_RATIO and bool(me["on_ground"]):
				return InputFrame.make(0, 0, false, false, false, false, true)
			var d := to_item.normalized()
			return InputFrame.make(d.x, d.y)
	return _fight(foe, my_pos, item_kind)


## Starts a guard on every other new threat and keeps it for bot_guard_ticks.
func _update_guard(foe: Dictionary, my_pos: Vector3) -> bool:
	var threat := not foe.is_empty() and _flat_delta(my_pos, foe["pos"]).length() <= _config.bot_guard_range \
			and (int(foe["state"]) == Fighter.State.ATTACK or int(foe["state"]) == Fighter.State.CHARGE)
	if threat and not _foe_was_threat:
		if _guard_next_threat:
			_guard_left = _config.bot_guard_ticks
		_guard_next_threat = not _guard_next_threat
	_foe_was_threat = threat
	if _guard_left > 0:
		_guard_left -= 1
		return true
	return false


func _use_throwable(foe: Dictionary, my_pos: Vector3) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	if delta.length() <= _config.bot_throw_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	return InputFrame.make(dir.x, dir.y)


func _fight(foe: Dictionary, my_pos: Vector3, item_kind: int) -> InputFrame:
	if foe.is_empty():
		return InputFrame.neutral()
	var delta := _flat_delta(my_pos, foe["pos"])
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var reach := _config.grab_forward + _config.grab_half_width + _config.fighter_radius
	if int(foe["state"]) == Fighter.State.GUARD and delta.length() <= reach:
		return InputFrame.make(dir.x, dir.y, false, false, false, false, true)
	if delta.length() <= _config.bot_attack_range and _cooldown == 0:
		_cooldown = _config.bot_attack_cooldown_ticks
		if item_kind != Item.Kind.BAT:
			_combo_left = combo_mash_ticks(_config)
		return InputFrame.make(dir.x, dir.y, false, true)
	return InputFrame.make(dir.x, dir.y)


static func _find(view: Dictionary, id: int) -> Dictionary:
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == id:
			return f
	return {}


static func _flat_delta(from: Vector3, to: Vector3) -> Vector2:
	return Vector2(to.x - from.x, to.z - from.z)


func _nearest_foe(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for f: Dictionary in view["fighters"]:
		if int(f["id"]) == _self_id or int(f["state"]) == Fighter.State.KO:
			continue
		var d := _flat_delta(my_pos, f["pos"]).length()
		if d < best_dist:
			best_dist = d
			best = f
	return best


func _nearest_item(view: Dictionary, my_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := _config.bot_item_seek_range
	for it: Dictionary in view.get("items", []):
		if int(it["state"]) != Item.State.GROUND or int(it["fuse_ticks"]) != Item.UNLIT:
			continue
		var d := _flat_delta(my_pos, it["pos"]).length()
		if d <= best_dist:
			best_dist = d
			best = it
	return best
