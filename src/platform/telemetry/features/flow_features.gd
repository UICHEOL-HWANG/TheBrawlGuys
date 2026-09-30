class_name FlowFeatures
extends RefCounted
## Match-flow features (platform A8, analytics-strategy §3.2/§3.4) from telemetry-enriched sim
## events (ringouts carry attacker_slot): longest true combo (hits landing while the target is still
## in HITSTUN from the same attacker), first blood (credited attacker of the first ringout), comeback
## (ever a stock behind the best opponent), first item pickup tick, contested pickups (a living
## opponent within CONTEST_RADIUS) and the context of an abandon.

const CONTEST_RADIUS := 2.0
const NONE := -1
const MS_PER_TICK := 1000.0 / SimTime.TICK_RATE

var _max_combo: PackedInt32Array
var _first_item: PackedInt32Array
var _contested: PackedInt32Array
var _behind: Array[bool] = []
var _combo: Dictionary = {}  # target -> [attacker, hits]
var _first_blood: int = NONE
var _any_ringout: bool = false
var _last_ringout_tick: int = NONE


func _init(slot_count: int) -> void:
	_max_combo.resize(slot_count)
	_contested.resize(slot_count)
	_first_item.resize(slot_count)
	_first_item.fill(NONE)
	for i: int in slot_count:
		_behind.append(false)


func observe(tick: int, events: Array, prev: Array, fighters: Array) -> void:
	for e: Dictionary in events:
		match String(e.get("type", "")):
			"hit":
				_on_hit(int(e["attacker"]), int(e["target"]), prev)
			"ringout":
				_on_ringout(int(e["id"]), int(e.get("attacker_slot", NONE)), tick)
			"item_pickup":
				_on_pickup(int(e["fighter"]), tick, fighters)
	_note_deficits(fighters)


func summary(slot: int, result: String) -> Dictionary:
	return {
		"max_combo": _max_combo[slot],
		"first_item_tick": _first_item[slot] if _first_item[slot] != NONE else null,
		"contested_pickups": _contested[slot],
		"first_blood": _any_ringout and _first_blood == slot,
		"comeback_win": _behind[slot] and result == "win",
	}


## match_abandoned context: local stocks minus the best opponent's, ms since the last ringout (-1 none).
func abandon_context(local_slot: int, fighters: Array, tick: int) -> Dictionary:
	var own := 0
	var best := 0
	for f: Dictionary in fighters:
		if int(f["id"]) == local_slot:
			own = int(f["stocks"])
		else:
			best = maxi(best, int(f["stocks"]))
	var since := roundi((tick - _last_ringout_tick) * MS_PER_TICK) if _last_ringout_tick != NONE else NONE
	return {"stock_diff": own - best, "ms_since_last_ringout": since}


func _on_hit(attacker: int, target: int, prev: Array) -> void:
	if attacker < 0 or attacker >= _max_combo.size():
		return
	var chain: Array = _combo.get(target, [NONE, 0])
	var stunned := int(_view_of(prev, target).get("state", NONE)) == Fighter.State.HITSTUN
	var hits := int(chain[1]) + 1 if stunned and int(chain[0]) == attacker else 1
	_combo[target] = [attacker, hits]
	_max_combo[attacker] = maxi(_max_combo[attacker], hits)


func _on_ringout(victim: int, attacker: int, tick: int) -> void:
	if not _any_ringout:
		_any_ringout = true
		_first_blood = attacker
	_last_ringout_tick = tick
	_combo.erase(victim)


func _on_pickup(slot: int, tick: int, fighters: Array) -> void:
	if slot < 0 or slot >= _first_item.size():
		return
	if _first_item[slot] == NONE:
		_first_item[slot] = tick
	var me := _view_of(fighters, slot)
	if me.is_empty():
		return
	for o: Dictionary in fighters:
		var other_alive := int(o["id"]) != slot and int(o["state"]) != Fighter.State.KO
		if other_alive and (o["pos"] as Vector3).distance_to(me["pos"] as Vector3) <= CONTEST_RADIUS:
			_contested[slot] += 1
			return


func _note_deficits(fighters: Array) -> void:
	for f: Dictionary in fighters:
		var slot := int(f["id"])
		if slot < 0 or slot >= _behind.size() or _behind[slot]:
			continue
		for o: Dictionary in fighters:
			if int(o["stocks"]) - int(f["stocks"]) >= 1:
				_behind[slot] = true
				break


static func _view_of(fighters: Array, slot: int) -> Dictionary:
	for f: Dictionary in fighters:
		if int(f["id"]) == slot:
			return f
	return {}
