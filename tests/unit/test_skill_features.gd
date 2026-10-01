extends GutTest
## Skill and context signals (event schema 8, SkillFeatures): reaction ticks, roll evades, tech
## attempts, DI use and angle, survived tumbles, choices at the edge / high damage, team assists.

const S := Fighter.State
const RADIUS := 10.0

var _sk: SkillFeatures
var _views: Array = []


func before_each() -> void:
	_sk = SkillFeatures.new(4)
	_views = []
	for i: int in 4:
		_views.append({"id": i, "spawn_id": 0, "pos": Vector3(i * 10, 0, 0), "state": S.IDLE, "damage": 0.0,
			"attack_kind": 0, "attack_ticks": 0, "hitstop_ticks": 0})


## One tick: per-slot view overrides, held buttons ({slot: {"guard": true, "x": 1.0, ...}}), events.
func _tick(tick: int, changes: Dictionary = {}, held: Dictionary = {}, events: Array = [], teams: Array = []) -> void:
	var prev := _views
	_views = []
	for i: int in prev.size():
		_views.append((prev[i] as Dictionary).merged(changes.get(i, {}), true))
	var inputs: Array = []
	for i: int in 4:
		var h: Dictionary = held.get(i, {})
		var f := InputFrame.new()
		f.guard = bool(h.get("guard", false))
		f.light = bool(h.get("light", false))
		f.move_x = float(h.get("x", 0.0))
		f.move_z = float(h.get("z", 0.0))
		inputs.append(f)
	_sk.observe(tick, events, prev, _views, RADIUS, inputs, teams)


func _p(slot: int) -> Dictionary:
	return _sk.summary(slot)


func test_columns_match_the_summary() -> void:
	assert_eq(_p(0).keys().size(), SkillFeatures.COLUMNS.size())
	for key: String in SkillFeatures.COLUMNS:
		assert_true(_p(0).has(key), key)
	assert_null(_p(0)["reaction_ticks_avg"], "no reactions yet")
	assert_null(_p(0)["di_perp_avg"], "no launches yet")


func test_guard_press_after_a_nearby_swing_is_a_reaction() -> void:
	_tick(1, {1: {"pos": Vector3(1, 0, 0)}})
	_tick(10, {1: {"state": S.ATTACK, "attack_kind": 1}}, {0: {"guard": true}})  # same tick: not a reaction
	_tick(11)
	_tick(15, {}, {0: {"guard": true}})
	assert_eq([_p(0)["threats_faced"], _p(0)["reactions"], _p(0)["reaction_ticks_avg"]], [1, 1, 5.0])
	assert_eq(_p(2)["threats_faced"], 0, "slot 2 is far away")


func test_dodging_through_a_swing_that_misses_is_an_evade() -> void:
	_tick(1, {1: {"pos": Vector3(1, 0, 0)}})
	_tick(2, {1: {"state": S.ATTACK, "attack_kind": 1}, 0: {"state": S.DODGE, "is_dodging": true}})
	_tick(3, {1: {"state": S.IDLE}, 0: {"state": S.IDLE, "is_dodging": false}})
	_tick(4, {1: {"state": S.ATTACK, "attack_kind": 2}, 0: {"state": S.DODGE, "is_dodging": true}})
	_tick(5, {}, {}, [{"type": "hit", "attacker": 1, "target": 0}])
	_tick(6, {1: {"state": S.IDLE}})
	assert_eq(_p(0)["roll_evades"], 1, "the second swing hit")


func test_tech_attempt_once_per_tumble() -> void:
	_tick(1, {0: {"tumbling": true}})
	_tick(2, {}, {0: {"guard": true}})
	_tick(3)
	_tick(4, {}, {0: {"guard": true}})
	_tick(5, {0: {"tumbling": false}})
	_tick(6, {0: {"tumbling": true}})
	_tick(7, {}, {0: {"guard": true}})
	assert_eq(_p(0)["tech_attempts"], 2)


func test_di_reads_the_stick_against_the_launch_motion() -> void:
	_tick(1, {1: {"state": S.HITSTUN, "hitstop_ticks": 1}}, {}, [{"type": "hit", "attacker": 0, "target": 1}])
	_tick(2, {1: {"hitstop_ticks": 0}}, {1: {"z": 1.0}})
	_tick(3, {1: {"pos": Vector3(12, 0, 0)}}, {1: {"z": 1.0}})  # DI tick: moving +x, stick sideways
	_tick(4, {}, {}, [{"type": "hit", "attacker": 0, "target": 1}])
	_tick(5, {1: {"pos": Vector3(14, 0, 0)}}, {1: {"x": 1.0}})  # stick along the launch
	_tick(6, {}, {}, [{"type": "hit", "attacker": 0, "target": 1}])
	_tick(7, {1: {"pos": Vector3(16, 0, 0)}})  # neutral
	assert_eq(_p(1)["di_inputs"], 2)
	assert_almost_eq(float(_p(1)["di_perp_avg"]), 1.0 / 3.0, 0.001, "sideways 1, along 0, neutral 0")


func test_tumble_survived_unless_rung_out() -> void:
	_tick(1, {0: {"tumbling": true}})
	_tick(2, {0: {"tumbling": false}})
	_tick(3, {0: {"tumbling": true}})
	_tick(4, {0: {"tumbling": false, "spawn_id": 1}}, {}, [{"type": "ringout", "id": 0}])
	assert_eq([_p(0)["tumbles"], _p(0)["tumbles_survived"]], [2, 1])


func test_choices_at_the_edge_and_at_high_damage() -> void:
	_tick(1, {0: {"pos": Vector3(9, 0, 0)}, 1: {"damage": 120.0}})
	_tick(2, {}, {0: {"guard": true}, 1: {"light": true}}, [{"type": "dodge", "fighter": 0, "kind": "roll"}])
	_tick(3, {}, {0: {"guard": true}, 1: {"light": true}})  # held: no new press
	assert_eq([_p(0)["edge_guard_presses"], _p(0)["edge_dodges"], _p(0)["edge_attack_presses"]], [1, 1, 0])
	assert_eq(_p(1)["high_dmg_attack_presses"], 1)
	assert_eq(_p(1)["high_dmg_ticks"], 2)
	assert_eq(_p(0)["high_dmg_guard_presses"], 0)


func test_team_assist_when_a_teammate_rings_out_my_victim() -> void:
	var teams := [0, 1, 0, 1]
	_tick(5, {}, {}, [{"type": "hit", "attacker": 2, "target": 1}], teams)
	_tick(6, {}, {}, [{"type": "hit", "attacker": 0, "target": 1}], teams)
	_tick(100, {}, {}, [{"type": "ringout", "id": 1, "attacker_slot": 0}], teams)
	_tick(110, {}, {}, [{"type": "hit", "attacker": 2, "target": 3}], teams)
	_tick(400, {}, {}, [{"type": "ringout", "id": 3, "attacker_slot": 0}], teams)
	assert_eq(_p(2)["team_assists"], 1, "the second hit was too long before the ring-out")
	assert_eq(_p(0)["team_assists"], 0, "the scorer does not assist himself")
