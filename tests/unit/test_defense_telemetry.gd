extends GutTest
## Defense and recovery tracking (event schema 8): dodge / guard break / perfect guard / knockdown /
## tech / getup sim events become SlotStats counters on match_ended.players[] and match_players,
## stay as raw match_events rows, and DI use is read from the launched fighter's stick.

const S := Fighter.State

var _sent: Array = []
var _t: MatchTelemetry
var _fighters: Array = []


func before_each() -> void:
	_sent.clear()
	_t = MatchTelemetry.new(func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s: %s" % [n, EventCatalog.validate(n, p)])
		_sent.append([n, p]))
	var slots: Array = []
	for i: int in 2:
		slots.append({"slot": i, "is_bot": i > 0, "character": "", "style": "classic",
			"input_device": "keyboard" if i == 0 else "bot"})
	_t.begin({"match_id": "m-d", "mode": "bot", "arena": "default", "seed": 1, "local_slot": 0,
		"started_at": "2026-10-01T12:00:00Z", "slots": slots})
	_fighters = [_f(0), _f(1)]


func _f(id: int) -> Dictionary:
	return {"id": id, "spawn_id": 0, "pos": Vector3.ZERO, "state": S.IDLE, "on_ground": true, "damage": 0.0,
		"stocks": 3, "attack_kind": 0, "attack_ticks": 0, "hitstop_ticks": 0}


func _stick(x: float) -> InputFrame:
	var f := InputFrame.new()
	f.move_x = x
	return f


## One tick: fighter overrides, sim events and per-slot stick x (0 = neutral).
func _tick(tick: int, events: Array = [], changes: Dictionary = {}, sticks: Array = [0.0, 0.0]) -> void:
	var next: Array = []
	for i: int in _fighters.size():
		next.append((_fighters[i] as Dictionary).merged(changes.get(i, {}), true))
	_fighters = next
	var view := {"tick": tick, "arena_radius": 10.0, "match_over": false, "winner": -1, "fighters": next,
		"items": [], "events": events}
	_t.on_frame(events, [], view, [_stick(sticks[0]), _stick(sticks[1])])


func _ended_player(slot: int) -> Dictionary:
	for s: Array in _sent:
		if s[0] == "match_ended":
			return s[1]["players"][slot]
	return {}


func _end() -> void:
	_t.end({"tick": 600, "arena_radius": 10.0, "match_over": true, "winner": 0, "fighters": _fighters})


func test_defense_events_become_counters() -> void:
	_tick(1, [{"type": "dodge", "fighter": 0, "kind": "roll", "dir": Vector3.RIGHT},
		{"type": "dodge", "fighter": 0, "kind": "air", "dir": Vector3.ZERO}])
	_tick(2, [{"type": "perfect_guard", "fighter": 0, "attacker": 1, "pos": Vector3.ZERO}])
	_tick(3, [{"type": "knockdown", "fighter": 1, "pos": Vector3.ZERO}])
	_tick(4, [{"type": "getup", "fighter": 1, "kind": "attack"}, {"type": "tech", "fighter": 0, "kind": "roll"}])
	_tick(5, [{"type": "getup", "fighter": 1, "kind": "roll"}, {"type": "getup", "fighter": 1, "kind": "stand"}])
	_end()
	var p0 := _ended_player(0)
	var p1 := _ended_player(1)
	assert_eq([p0["dodges_roll"], p0["dodges_air"], p0["perfect_guards"], p0["techs"]], [1, 1, 1, 1])
	assert_eq([p1["knockdowns"], p1["getups_stand"], p1["getups_roll"], p1["getups_attack"]], [1, 1, 1, 1])
	assert_eq(_t.player_rows()[1]["knockdowns"], 1, "match_players carries the same counters")


func test_guard_break_is_credited_to_the_last_blocked_hitter() -> void:
	_tick(10, [{"type": "guard_hit", "attacker": 1, "target": 0, "pos": Vector3.ZERO}])
	_tick(20, [{"type": "guard_break", "fighter": 0, "pos": Vector3.ZERO}])
	_tick(200, [{"type": "guard_break", "fighter": 0, "pos": Vector3.ZERO}])
	_end()
	assert_eq(_ended_player(0)["guard_breaks"], 2)
	assert_eq(_ended_player(1)["guard_breaks_caused"], 1, "the second break was guard held until empty")
	var breaks := _t.event_rows().filter(func(r: Dictionary) -> bool: return r["type"] == "guard_break")
	assert_eq(breaks[0]["actor_slot"], 0)
	assert_eq(breaks[0]["payload"]["attacker_slot"], 1)
	assert_eq(breaks[1]["payload"]["attacker_slot"], -1)


func test_di_counts_a_held_stick_on_the_first_tick_after_hitstop() -> void:
	_tick(1, [{"type": "hit", "attacker": 0, "target": 1, "pos": Vector3.ZERO}], {1: {"state": S.HITSTUN,
		"hitstop_ticks": 2}}, [0.0, 1.0])
	_tick(2, [], {1: {"hitstop_ticks": 1}}, [0.0, 1.0])
	_tick(3, [], {1: {"hitstop_ticks": 0}}, [0.0, 1.0])
	_tick(4, [], {}, [0.0, 0.0])  # DI tick: neutral stick
	_tick(5, [{"type": "hit", "attacker": 0, "target": 1, "pos": Vector3.ZERO}], {}, [0.0, 0.0])
	_tick(6, [], {}, [0.0, -1.0])  # DI tick: stick held
	_tick(7, [{"type": "hit", "attacker": 1, "target": 0, "pos": Vector3.ZERO}], {}, [0.0, 0.0])
	_tick(8, [], {}, [1.0, 0.0])  # P1 never left IDLE in this view: no DI
	_end()
	assert_eq(_ended_player(1)["hits_taken"], 2)
	assert_eq(_ended_player(1)["di_inputs"], 1)
	assert_eq(_ended_player(0)["hits_taken"], 1)
	assert_eq(_ended_player(0)["di_inputs"], 0)


func test_raw_rows_name_the_actor_and_target() -> void:
	_tick(1, [{"type": "perfect_guard", "fighter": 0, "attacker": 1, "pos": Vector3.ZERO},
		{"type": "projectile_spawn", "id": 4, "owner": 1, "kind": 0, "pos": Vector3.ZERO},
		{"type": "tech", "fighter": 0, "kind": "place"}])
	var rows := _t.event_rows()
	assert_eq([rows[0]["actor_slot"], rows[0]["target_slot"]], [1, 0], "perfect guard: attacker -> guarder")
	assert_eq(rows[1]["actor_slot"], 1, "projectile owner")
	assert_eq(rows[1]["payload"]["id"], 4)
	assert_eq([rows[2]["actor_slot"], rows[2]["payload"]["kind"]], [0, "place"])
