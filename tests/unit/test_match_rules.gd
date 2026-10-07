extends GutTest
## MatchRules (modes as data): stock / team (2v2) / timed FFA, default teams, ally masks, the
## per-mode builder from a GameConfig and the plain-data round trip.


func test_stock_is_the_default() -> void:
	var r := MatchRules.new()
	assert_eq(r.mode, MatchRules.STOCK)
	assert_eq(r.team_of(0), MatchRules.NO_TEAM)
	assert_false(r.allies(0, 1))


func test_team_mode_defaults_to_p1_p3_against_p2_p4() -> void:
	var r := MatchRules.for_mode(MatchRules.TEAM, 4, GameConfig.new())
	assert_eq(r.teams, [0, 1, 0, 1] as Array[int])
	assert_true(r.allies(0, 2))
	assert_true(r.allies(1, 3))
	assert_false(r.allies(0, 1))
	assert_false(r.allies(0, 0), "nobody is their own ally")


func test_friendly_fire_off_shields_teammates_only() -> void:
	var r := MatchRules.team([0, 1, 0, 1] as Array[int], false)
	assert_eq(r.ally_mask(0), 1 << 2)
	assert_eq(r.ally_mask(3), 1 << 1)
	var on := MatchRules.team([0, 1, 0, 1] as Array[int], true)
	assert_eq(on.ally_mask(0), 0, "friendly fire on: teammates hit each other")


func test_timed_mode_reads_duration_and_config_friendly_fire() -> void:
	var c := GameConfig.new()
	c.timed_duration = 30.0
	var r := MatchRules.for_mode(MatchRules.TIMED, 4, c)
	assert_eq(r.duration_ticks, SimTime.to_ticks(30.0))
	assert_eq(r.ally_mask(0), 0)
	assert_eq(MatchRules.for_mode(MatchRules.TEAM, 4, c).friendly_fire, c.friendly_fire == 1)


func test_config_defaults() -> void:
	var c := GameConfig.new()
	assert_eq(c.timed_duration, 120.0)
	assert_eq(c.friendly_fire, 0, "friendly fire off by default")
	assert_true(GameConfig.SIM_GROUPS.has("Modes"))


func test_unknown_mode_falls_back_to_stock() -> void:
	assert_eq(MatchRules.for_mode("nope", 2, GameConfig.new()).mode, MatchRules.STOCK)


func test_data_round_trip() -> void:
	var r := MatchRules.team([0, 1, 0, 1] as Array[int], true)
	var back := MatchRules.from_data(r.to_data())
	assert_not_null(back)
	assert_eq(back.mode, MatchRules.TEAM)
	assert_eq(back.teams, r.teams)
	assert_true(back.friendly_fire)
	var t := MatchRules.from_data(MatchRules.timed(600).to_data())
	assert_eq(t.duration_ticks, 600)


func test_from_data_rejects_bad_input() -> void:
	assert_null(MatchRules.from_data({}))
	assert_null(MatchRules.from_data({"mode": "x", "teams": [], "friendly_fire": false, "duration_ticks": 0}))
	assert_null(MatchRules.from_data({"mode": "team", "teams": ["a"], "friendly_fire": false, "duration_ticks": 0}))


func test_team_mode_takes_chosen_teams() -> void:
	var c := GameConfig.new()
	var r := MatchRules.for_mode(MatchRules.TEAM, 4, c, [0, 0, 1, 1] as Array[int])
	assert_eq(r.teams, [0, 0, 1, 1] as Array[int])
	assert_true(r.allies(0, 1))
	assert_false(r.allies(0, 2))
	assert_eq(r.ally_mask(0), 1 << 1, "friendly fire off: P2 shields P1")
	assert_eq(MatchRules.for_mode(MatchRules.TEAM, 4, c, [] as Array[int]).teams, [0, 1, 0, 1] as Array[int],
			"no choice: the default split")
	assert_eq(MatchRules.for_mode(MatchRules.STOCK, 2, c, [0, 0] as Array[int]).teams.size(), 0,
			"other modes ignore teams")


func test_two_vs_two_check() -> void:
	assert_true(MatchRules.is_two_vs_two([0, 1, 0, 1] as Array[int]))
	assert_true(MatchRules.is_two_vs_two([1, 0, 0, 1] as Array[int]))
	assert_false(MatchRules.is_two_vs_two([0, 0, 0, 1] as Array[int]), "3 vs 1")
	assert_false(MatchRules.is_two_vs_two([0, 1, 0] as Array[int]), "three fighters")
	assert_false(MatchRules.is_two_vs_two([0, 2, 1, 1] as Array[int]), "no third team")
