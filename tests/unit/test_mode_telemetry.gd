extends GutTest
## Match rule telemetry (combat-depth D, event schema 7): "rule" on match events and the matches
## row (stock rows keep the 0003 shape), teammates of the winner win, players[] / match_players
## carry team (team mode) and score (timed).

var _sent: Array = []


func _telemetry(rule: String, count: int) -> MatchTelemetry:
	_sent.clear()
	var t := MatchTelemetry.new(func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s: %s" % [n, EventCatalog.validate(n, p)])
		_sent.append([n, p]))
	var slots: Array = []
	for i: int in count:
		slots.append({"slot": i, "is_bot": i > 0, "character": "", "style": "classic",
			"input_device": "keyboard" if i == 0 else "bot"})
	t.begin({"match_id": "m-9", "mode": "bot", "rule": rule, "arena": "default", "seed": 1, "local_slot": 0,
		"started_at": "2026-10-01T12:00:00Z", "slots": slots})
	return t


func _view(mode: Dictionary, winner: int, count: int) -> Dictionary:
	var fighters: Array = []
	for i: int in count:
		fighters.append({"id": i, "pos": Vector3.ZERO, "state": Fighter.State.IDLE, "damage": 0.0, "stocks": 1})
	return {"tick": 600, "arena_radius": 10.0, "match_over": true, "winner": winner, "fighters": fighters,
		"items": [], "events": [], "mode": mode}


func _props(event_name: String) -> Dictionary:
	for s: Array in _sent:
		if s[0] == event_name:
			return s[1]
	return {}


func test_match_events_carry_the_rule() -> void:
	var t := _telemetry(MatchRules.TIMED, 2)
	assert_eq(_props("match_started")["rule"], MatchRules.TIMED)
	t.end(_view({"rule": MatchRules.TIMED, "teams": [], "scores": [3, 1]}, 0, 2))
	assert_eq(_props("match_ended")["rule"], MatchRules.TIMED)
	var players: Array = _props("match_ended")["players"]
	assert_eq([int(players[0]["score"]), int(players[1]["score"])], [3, 1])
	assert_eq(t.match_row()["rule"], MatchRules.TIMED)
	assert_eq(int(t.player_rows()[0]["score"]), 3)


func test_teammates_of_the_winner_win() -> void:
	var t := _telemetry(MatchRules.TEAM, 4)
	t.end(_view({"rule": MatchRules.TEAM, "teams": [0, 1, 0, 1], "scores": [0, 0, 0, 0]}, 2, 4))
	var results: Array = (_props("match_ended")["players"] as Array).map(func(p: Dictionary) -> String:
		return p["result"])
	assert_eq(results, ["win", "loss", "win", "loss"])
	assert_eq(_props("match_ended")["result"], "win", "P1 wins with teammate P3")
	assert_eq(int(t.player_rows()[1]["team"]), 1)


func test_stock_rows_keep_the_old_shape() -> void:
	var t := _telemetry(MatchRules.STOCK, 2)
	t.end(_view({"rule": MatchRules.STOCK, "teams": [], "scores": [0, 0]}, 0, 2))
	assert_false(t.match_row().has("rule"), "matches.rule is sent only for team / timed (0004)")
	assert_false(t.player_rows()[0].has("team"))
	assert_false(t.player_rows()[0].has("score"))
	assert_eq(_props("match_ended")["rule"], MatchRules.STOCK, "Amplitude always gets the rule")
