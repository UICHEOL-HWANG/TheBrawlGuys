extends GutTest
## Special-move tracking (Phase 5 T10, docs/tracking-plan.md §3.5): gauge_full, special_used and
## special_hit (one per activation, sent once its ring-out window is decided) plus the specials /
## special_hits slot counters, from a fixed synthetic sim event sequence.

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


func _ringout(tick: int, victim: int) -> void:
	_frame(tick, [{"type": "ringout", "id": victim, "pos": Vector3(20, -5, 0), "stocks_left": 2}],
			{victim: {"spawn_id": 1, "stocks": 2, "damage": 0.0}})


func test_gauge_full_names_the_slot_character_and_match_time() -> void:
	_full(90, 1, "mage")
	assert_eq(_names(), ["match_started", "gauge_full"])
	var p := _props("gauge_full")
	assert_eq(p["slot"], 1)
	assert_eq(p["character"], "mage")
	assert_almost_eq(float(p["match_time_s"]), 1.5, 0.001)


func test_special_used_measures_time_since_full_and_the_nearest_foe_damage() -> void:
	_full(60, 0, "barbarian")
	_start(90, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	var p := _props("special_used")
	assert_eq(p["slot"], 0)
	assert_eq(p["character"], "barbarian")
	assert_eq(p["special"], SpecialCatalog.GROUND_SLAM)
	assert_eq(p["ms_since_full"], 500)
	assert_almost_eq(float(p["target_damage"]), 40.0, 0.001, "slot 1 is the nearest living foe")


func test_special_used_without_a_seen_gauge_full_reports_minus_one() -> void:
	_start(10, 2, "knight", SpecialCatalog.SPIN_SLASH)
	assert_eq(_props("special_used")["ms_since_full"], -1)


func test_special_hit_waits_for_the_ringout_window_then_reports_one_activation() -> void:
	_start(10, 2, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(20, 2, 0, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(21, 2, 1, "knight", SpecialCatalog.SPIN_SLASH)
	assert_false(_names().has("special_hit"), "held until the ring-out is decided")
	_frame(20 + StockLoss.WINDOW_TICKS + 1)
	assert_eq(_names().count("special_hit"), 1, "first hit of the activation only")
	var p := _props("special_hit")
	assert_eq(p["slot"], 2)
	assert_eq(p["character"], "knight")
	assert_eq(p["targets_hit"], 2)
	assert_eq(p["target_slot"], 0, "first target")
	assert_false(p["caused_ringout"])


func test_special_hit_followed_by_the_target_ringing_out_is_sent_at_once() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_ringout(80, 1)
	assert_eq(_names().count("special_hit"), 1)
	assert_true(_props("special_hit")["caused_ringout"])
	_frame(400)
	assert_eq(_names().count("special_hit"), 1, "not sent twice")


func test_open_special_hit_is_flushed_before_match_ended() -> void:
	_start(10, 1, "mage", SpecialCatalog.BIG_FIREBALL)
	_special_hit(40, 1, 2, "mage", SpecialCatalog.BIG_FIREBALL)
	_view["match_over"] = true
	_view["winner"] = 1
	_t.end(_view)
	var names := _names()
	assert_true(names.find("special_hit") >= 0 and names.find("special_hit") < names.find("match_ended"))


func test_slot_summaries_count_specials_and_special_hits() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 2, "barbarian", SpecialCatalog.GROUND_SLAM)
	_start(300, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_view["match_over"] = true
	_view["winner"] = 0
	_t.end(_view)
	var p0: Dictionary = _props("match_ended")["players"][0]
	assert_eq(p0["specials"], 2)
	assert_eq(p0["special_hits"], 2)
	assert_eq(_t.player_rows()[0]["specials"], 2, "match_players.specials")
	assert_eq(_t.player_rows()[0]["special_hits"], 2)
	assert_eq(_props("match_ended")["players"][1]["specials"], 0)
