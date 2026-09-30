extends GutTest
## Shared rig for the special tracking tests (test_special_telemetry, test_special_ringout): a
## three-slot MatchTelemetry fed synthetic sim events, with catalog validation on every send.

const K := AttackSet.Kind
const S := Fighter.State

var _sent: Array = []
var _t: MatchTelemetry
var _view: Dictionary


func before_each() -> void:
	_sent.clear()
	_t = MatchTelemetry.new(func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s matches the catalog: %s" % [n, EventCatalog.validate(n, p)])
		_sent.append([n, p]))
	_t.begin({
		"match_id": "m-s", "mode": "bot", "arena": "default", "seed": 1, "local_slot": 0,
		"started_at": "2026-09-30T12:00:00Z",
		"slots": [
			{"slot": 0, "is_bot": false, "character": "barbarian", "style": "boxer", "input_device": "keyboard"},
			{"slot": 1, "is_bot": true, "character": "mage", "style": "ranged", "input_device": "bot"},
			{"slot": 2, "is_bot": true, "character": "knight", "style": "weapon", "input_device": "bot"},
		],
	})
	_view = {"tick": 0, "arena_radius": 10.0, "match_over": false, "winner": -1,
		"fighters": [_f(0, 0.0), _f(1, 40.0), _f(2, 90.0)], "items": [], "events": []}


func _f(id: int, damage: float) -> Dictionary:
	return {"id": id, "spawn_id": 0, "pos": Vector3(id * 2.0, 0, 0), "state": S.IDLE, "on_ground": true,
		"damage": damage, "stocks": 3, "attack_kind": -1, "attack_ticks": 0}


func _frame(tick: int, events: Array = [], changes: Dictionary = {}) -> void:
	var fighters: Array = []
	for f: Dictionary in _view["fighters"]:
		fighters.append(f.duplicate())
	for id: int in changes:
		fighters[id].merge(changes[id], true)
	_view = _view.duplicate()
	_view["fighters"] = fighters
	_view["tick"] = tick
	_t.on_frame(events, [], _view)


func _names() -> Array[String]:
	var out: Array[String] = []
	for s: Array in _sent:
		out.append(String(s[0]))
	return out


func _props(event_name: String, nth: int = 0) -> Dictionary:
	var seen := 0
	for s: Array in _sent:
		if s[0] == event_name:
			if seen == nth:
				return s[1]
			seen += 1
	return {}


func _full(tick: int, slot: int, character: String) -> void:
	_frame(tick, [{"type": "gauge_full", "fighter": slot, "character": character, "pos": Vector3.ZERO}])


func _start(tick: int, slot: int, character: String, special: String) -> void:
	_frame(tick, [{"type": "special_start", "fighter": slot, "character": character, "special": special,
		"pos": Vector3.ZERO}], {slot: {"state": S.SPECIAL, "attack_kind": K.SPECIAL}})


func _special_hit(tick: int, attacker: int, target: int, character: String, special: String) -> void:
	_frame(tick, [
		{"type": "hit", "attacker": attacker, "target": target, "attack_kind": K.SPECIAL, "pos": Vector3.ZERO,
			"knockback": 9.0, "damage": 15.0, "hitstop_ticks": 6},
		{"type": "special_hit", "attacker": attacker, "target": target, "pos": Vector3.ZERO, "knockback": 9.0,
			"character": character, "special": special},
	])


func _ringout(tick: int, victim: int, extra: Array = []) -> void:
	var events: Array = extra.duplicate()
	events.append({"type": "ringout", "id": victim, "pos": Vector3(20, -5, 0), "stocks_left": 2})
	_frame(tick, events, {victim: {"spawn_id": 1, "stocks": 2, "damage": 0.0}})


