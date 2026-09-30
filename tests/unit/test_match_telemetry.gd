extends GutTest
## Match telemetry (platform A6, PRD-DATA-03/04): a fixed synthetic sequence of sim and view
## events must produce the expected Amplitude events, slot summaries and Supabase rows.

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
	_t.begin(_setup())
	_view = {"tick": 0, "arena_radius": 10.0, "match_over": false, "winner": -1,
		"fighters": [_f(0), _f(1)], "items": [], "events": []}


func _setup() -> Dictionary:
	return {
		"match_id": "m-1", "mode": "bot", "arena": "default", "seed": 7, "local_slot": 0,
		"started_at": "2026-09-30T12:00:00Z", "build_version": "0.4.0", "platform": "desktop",
		"slots": [
			{"slot": 0, "is_bot": false, "character": "Knight", "style": "default", "input_device": "keyboard"},
			{"slot": 1, "is_bot": true, "character": "Barbarian", "style": "default", "input_device": "bot"},
		],
	}


func _f(id: int) -> Dictionary:
	return {"id": id, "spawn_id": 0, "pos": Vector3(id, 0, 0), "state": S.IDLE, "on_ground": true,
		"damage": 0.0, "stocks": 3, "attack_kind": 0, "attack_ticks": 0}


## Advances the view to tick with fighter overrides, then feeds one frame.
func _frame(tick: int, events: Array = [], view_events: Array = [], changes: Dictionary = {}) -> void:
	var fighters: Array = []
	for f: Dictionary in _view["fighters"]:
		fighters.append(f.duplicate())
	for id: int in changes:
		fighters[id].merge(changes[id], true)
	_view = _view.duplicate()
	_view["fighters"] = fighters
	_view["tick"] = tick
	_view["events"] = events
	_t.on_frame(events, view_events, _view)


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


func _play_scenario() -> void:
	_frame(1)
	_frame(2, [], [], {0: {"state": S.ATTACK, "attack_kind": K.LIGHT_1, "attack_ticks": 0}})
	_frame(3, [{"type": "hit", "attacker": 0, "target": 1, "attack_kind": K.LIGHT_1, "pos": Vector3.ZERO}],
			[], {1: {"damage": 5.0, "state": S.HITSTUN}})
	_frame(4, [], [], {0: {"state": S.IDLE}, 1: {"state": S.IDLE}})
	_frame(5, [], [], {1: {"state": S.ATTACK, "attack_kind": K.HEAVY}})
	_frame(6, [], [], {1: {"state": S.IDLE}})
	_frame(7, [{"type": "item_pickup", "id": 3, "kind": Item.Kind.BAT, "fighter": 0, "pos": Vector3.ZERO}])
	_frame(8, [], [], {0: {"state": S.ATTACK, "attack_kind": K.BAT}})
	_frame(9, [{"type": "hit", "attacker": 0, "target": 1, "attack_kind": K.BAT, "pos": Vector3.ZERO}],
			[], {1: {"damage": 17.0}})
	_frame(10, [], [], {0: {"state": S.IDLE}})
	_frame(11, [], [{"type": "jumped", "id": 1, "pos": Vector3.ZERO}])
	_frame(100, [{"type": "ringout", "id": 1, "pos": Vector3(20, -5, 0), "stocks_left": 2}],
			[{"type": "respawned", "id": 1, "pos": Vector3(0, 6, 0)}], {1: {"spawn_id": 1, "damage": 0.0, "stocks": 2}})
	_frame(400, [{"type": "ringout", "id": 0, "pos": Vector3(0, -20, -15), "stocks_left": 2}],
			[], {0: {"spawn_id": 1, "stocks": 2}})
	_frame(500, [{"type": "gimmick_damage", "kind": "campfire", "target": 1, "pos": Vector3.ZERO}])
	_frame(520, [{"type": "ringout", "id": 1, "pos": Vector3(0, -9, 3), "stocks_left": 1}],
			[], {1: {"spawn_id": 2, "stocks": 1}})
	_frame(600, [], [], {})
	_view["match_over"] = true
	_view["winner"] = 0
	_t.end(_view)


func test_match_started_describes_the_setup() -> void:
	assert_eq(_names(), ["match_started"])
	var p := _props("match_started")
	assert_eq(p["match_id"], "m-1")
	assert_eq(p["player_count"], 2)
	assert_eq(p["bot_count"], 1)
	assert_eq(p["characters"], ["Knight", "Barbarian"])
	assert_eq(p["input_device"], "keyboard")


func test_scenario_event_sequence() -> void:
	_play_scenario()
	assert_eq(_names(), ["match_started", "item_picked_up", "item_used", "item_hit", "stock_lost", "stock_lost",
		"gimmick_triggered", "stock_lost", "gimmick_ringout", "match_ended"])
	assert_eq(_props("item_used")["action"], "swing")
	assert_eq(_props("item_used")["item"], "bat")
	assert_eq(_props("item_hit")["target_slot"], 1)
	assert_false(_props("item_hit")["guarded"])
	assert_eq(_props("gimmick_triggered")["kind"], "campfire")


func test_stock_lost_classification() -> void:
	_play_scenario()
	var knock := _props("stock_lost", 0)
	assert_eq(knock["victim_slot"], 1)
	assert_eq(knock["attacker_slot"], 0)
	assert_eq(knock["cause"], "knockback")
	assert_almost_eq(float(knock["damage_at_death"]), 17.0, 0.001)
	assert_eq(knock["angle_deg"], 0)
	assert_eq(knock["zone"], "E")
	assert_eq(knock["stocks_left"], 2)
	var fall := _props("stock_lost", 1)
	assert_eq(fall["victim_slot"], 0)
	assert_eq(fall["attacker_slot"], -1)
	assert_eq(fall["cause"], "self")
	assert_eq(fall["angle_deg"], 90, "-z is north")
	assert_eq(fall["zone"], "N")
	var burn := _props("stock_lost", 2)
	assert_eq(burn["cause"], "gimmick")
	assert_eq(burn["zone"], "below", "fell inside the arena radius")
	assert_eq(_props("gimmick_ringout")["kind"], "campfire")


func test_match_ended_summaries() -> void:
	_play_scenario()
	var p := _props("match_ended")
	assert_eq(p["result"], "win")
	assert_eq(p["winner_slot"], 0)
	assert_almost_eq(float(p["duration_s"]), 10.0, 0.001)
	var p0: Dictionary = p["players"][0]
	var p1: Dictionary = p["players"][1]
	assert_eq(p0["hits"], 2)
	assert_almost_eq(float(p0["damage_dealt"]), 17.0, 0.001)
	assert_eq(p0["whiffs"], 0)
	assert_eq(p0["items_used"], 1)
	assert_eq(p0["ringouts_scored"], 1)
	assert_eq(p0["falls"], 1)
	assert_eq(p0["result"], "win")
	assert_almost_eq(float(p1["damage_taken"]), 17.0, 0.001)
	assert_eq(p1["whiffs"], 1, "the heavy hit nothing")
	assert_eq(p1["jumps"], 1)
	assert_eq(p1["falls"], 2)
	assert_eq(p1["falls_by_gimmick"], 1)
	assert_eq(p1["result"], "loss")
	assert_eq([p0["character"], p0["style"]], ["Knight", "default"], "per-style summary: who played what")
	assert_eq([p1["character"], p1["style"]], ["Barbarian", "default"])


func test_guard_and_grab_counts() -> void:
	_frame(1)
	_frame(2, [{"type": "guard_hit", "attacker": 1, "target": 0, "attack_kind": K.LIGHT_1, "pos": Vector3.ZERO}])
	_frame(3, [{"type": "grab", "attacker": 0, "target": 1, "pos": Vector3.ZERO}])
	_t.end(_view, true)
	var s := _t.player_rows()
	assert_eq(s[0]["guards"], 1)
	assert_eq(s[0]["grabs"], 1)
	assert_eq(s[1]["hits"], 0, "a guarded hit is not a hit")


func test_item_throw_and_explosion() -> void:
	_frame(1, [{"type": "item_pickup", "id": 5, "kind": Item.Kind.BOMB, "fighter": 1, "pos": Vector3.ZERO}])
	_frame(2, [{"type": "item_throw", "id": 5, "kind": Item.Kind.BOMB, "fighter": 1, "pos": Vector3.ZERO}])
	_frame(3, [{"type": "explosion", "id": 5, "pos": Vector3.ZERO, "radius": 2.0},
		{"type": "hit", "attacker": 1, "target": 0, "attack_kind": K.BOMB, "pos": Vector3.ZERO}])
	assert_eq(_names(), ["match_started", "item_picked_up", "item_used", "item_used", "item_hit"])
	assert_eq(_props("item_used", 0)["action"], "throw")
	assert_eq(_props("item_used", 1)["action"], "explode")
	assert_eq(_props("item_used", 1)["slot"], 1, "explosion owner from the throw")
	assert_eq(_props("item_hit")["item"], "bomb")


func test_abandoned_match() -> void:
	_frame(120)
	_t.end(_view, true)
	assert_eq(_names(), ["match_started", "match_abandoned"])
	assert_almost_eq(float(_props("match_abandoned")["duration_s"]), 2.0, 0.001)
	assert_eq(_t.match_row()["result"], "abandoned")
	assert_false(_t.is_active())


func test_end_is_idempotent() -> void:
	_t.end(_view, true)
	_t.end(_view, true)
	assert_eq(_names().count("match_abandoned"), 1)


func test_raw_rows() -> void:
	_play_scenario()
	var rows := _t.event_rows()
	var types: Array[String] = []
	for r: Dictionary in rows:
		assert_eq(r["match_id"], "m-1")
		assert_true(JsonSafe.is_safe(r), "rows are JSON-safe")
		types.append(String(r["type"]))
	assert_eq(types.count("hit"), 2)
	assert_eq(types.count("ringout"), 3)
	assert_eq(types.count("jumped"), 1)
	assert_eq(types.count("respawned"), 1)
	assert_eq(types.count("gimmick_damage"), 1)
	assert_eq(types.count("pos"), 2, "one sample per fighter on tick 600")
	var hit: Dictionary = rows[types.find("hit")]
	assert_eq(hit["tick"], 3)
	assert_eq(hit["actor_slot"], 0)
	assert_eq(hit["target_slot"], 1)
	assert_eq(hit["payload"]["pos"], [0.0, 0.0, 0.0])
	var ringout: Dictionary = rows[types.find("ringout")]
	assert_eq(ringout["actor_slot"], 1)
	assert_null(ringout["target_slot"])
	for r: Dictionary in rows:
		assert_eq(r.keys().size(), 6, "every row has the same columns for bulk insert")


func test_position_samples_every_30_ticks() -> void:
	for tick: int in range(1, 91):
		_frame(tick)
	var pos := _t.event_rows().filter(func(r: Dictionary) -> bool: return r["type"] == "pos")
	assert_eq(pos.size(), 6)
	assert_eq(pos[0]["tick"], 30)
	assert_eq(pos[0]["payload"]["pos"], [0.0, 0.0, 0.0])


func test_match_and_player_rows() -> void:
	_play_scenario()
	var m := _t.match_row()
	assert_eq(m["id"], "m-1")
	assert_eq(m["mode"], "bot")
	assert_eq(m["player_count"], 2)
	assert_eq(m["seed"], 7)
	assert_eq(m["duration_ticks"], 600)
	assert_eq(m["winner_slot"], 0)
	assert_eq(m["result"], "win")
	assert_eq(m["started_at"], "2026-09-30T12:00:00Z")
	var players := _t.player_rows()
	assert_eq(players.size(), 2)
	assert_eq(players[1]["match_id"], "m-1")
	assert_eq(players[1]["character"], "Barbarian")
	assert_true(players[1]["is_bot"])
	assert_eq(players[1]["stocks_left"], 1)


func test_slot_summaries_carry_the_behaviour_features() -> void:
	_play_scenario()
	var p0: Dictionary = _props("match_ended")["players"][0]
	for key: String in MatchFeatures.COLUMNS:
		assert_true(p0.has(key), "match_ended.players has %s" % key)
		assert_true(_t.player_rows()[0].has(key), "match_players row has %s" % key)
	assert_almost_eq(float(p0["hit_accuracy"]), 1.0, 0.001, "two swings, two hits")
	assert_eq(p0["first_item_tick"], 7)
	assert_true(p0["first_blood"], "slot 0 is credited with the first ringout")
	assert_eq(_props("match_started")["loss_streak"], 0, "no session context in this setup")


func test_abandon_names_the_stock_gap_and_time_since_the_last_ringout() -> void:
	_frame(60, [{"type": "ringout", "id": 0, "pos": Vector3(0, -20, 0), "stocks_left": 2}], [],
			{0: {"spawn_id": 1, "stocks": 2}})
	_frame(180)
	_t.end(_view, true)
	var p := _props("match_abandoned")
	assert_eq(p["stock_diff"], -1)
	assert_eq(p["ms_since_last_ringout"], 2000)
