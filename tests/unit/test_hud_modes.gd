extends GutTest
## HUD per match rule (combat-depth D): team 2v2 groups P1 + P3 in a "팀 1" frame at the left and
## P2 + P4 in a "팀 2" frame at the right with team-tinted badges; timed shows the clock between
## the slots and scores in place of stocks, red for the final 10 s; result wording per rule.

const TEAM_MODE := {"rule": "team", "teams": [0, 1, 0, 1], "scores": [0, 0, 0, 0], "ticks_left": 0,
	"sudden_death": false, "winner_team": -1}


func _hud(count: int, mode: Dictionary) -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(count, 3, mode)
	return hud


func _fighters(count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append({"id": i, "damage": 10.0 * i, "stocks": 3, "state": Fighter.State.IDLE})
	return out


func _timed(ticks_left: int, scores: Array, sudden: bool = false) -> Dictionary:
	return {"rule": "timed", "teams": [], "scores": scores, "ticks_left": ticks_left, "sudden_death": sudden,
		"winner_team": -1}


func test_team_frames_group_teammates_left_and_right() -> void:
	var hud := _hud(4, TEAM_MODE)
	await wait_process_frames(2)
	var frames := hud.slots().frames
	assert_eq(frames.size(), 2)
	assert_eq([frames[0].header_text(), frames[1].header_text()], ["팀 1", "팀 2"])
	assert_lt(frames[0].get_global_rect().position.x, frames[1].get_global_rect().position.x, "team 1 left")
	assert_true(frames[0].is_ancestor_of(hud.slots().counters[0]), "P1 in team 1")
	assert_true(frames[0].is_ancestor_of(hud.slots().counters[2]), "P3 in team 1")
	assert_true(frames[1].is_ancestor_of(hud.slots().counters[3]), "P4 in team 2")
	assert_false(frames[0].get_global_rect().intersects(frames[1].get_global_rect()))


func test_team_mode_still_counts_stocks() -> void:
	var hud := _hud(4, TEAM_MODE)
	var fighters := _fighters(4)
	fighters[3]["stocks"] = 1
	hud.update_from({"fighters": fighters, "mode": TEAM_MODE})
	assert_eq(hud.stocks_shown(3), 1)
	assert_eq(hud.counter_text(2), "20%")


func test_timed_shows_the_clock_and_scores() -> void:
	var hud := _hud(4, _timed(SimTime.to_ticks(120.0), [0, 0, 0, 0]))
	hud.update_from({"fighters": _fighters(4), "mode": _timed(SimTime.to_ticks(95.0), [2, -1, 0, 0])})
	var slots := hud.slots()
	assert_not_null(slots.timer)
	assert_eq(slots.timer.text(), "1:35")
	assert_false(slots.timer.is_final())
	assert_eq(slots.scores[0].text, "2점")
	assert_eq(slots.scores[1].text, "-1점")
	assert_null(slots.stocks[0], "scores replace stocks")
	assert_eq(slots.timer.get_index(), slots.counters[1].get_parent().get_index() + 2, "clock in the middle")


func test_final_ten_seconds_turn_red_and_sudden_death_says_so() -> void:
	var hud := _hud(2, _timed(600, [0, 0]))
	hud.update_from({"fighters": _fighters(2), "mode": _timed(SimTime.to_ticks(9.5), [0, 0])})
	assert_eq(hud.slots().timer.text(), "0:10")
	assert_true(hud.slots().timer.is_final())
	hud.update_from({"fighters": _fighters(2), "mode": _timed(0, [1, 1], true)})
	assert_eq(hud.slots().timer.text(), MatchTimer.SUDDEN_DEATH_TEXT)


func test_stock_has_no_frames_or_clock() -> void:
	var hud := _hud(2, {})
	assert_null(hud.slots().timer)
	assert_true(hud.slots().frames.is_empty())


func test_result_wording_per_rule() -> void:
	var team := ResultText.of(2, 0, TEAM_MODE.merged({"winner_team": 0}, true))
	assert_eq(team["title"], "승리!", "P1 wins with P3")
	assert_eq(team["detail"], "팀 1 승리 · P1 · P3")
	assert_eq(ResultText.of(1, ResultText.NO_LOCAL, TEAM_MODE.merged({"winner_team": 1}, true))["title"], "팀 2 승리!")
	assert_eq(ResultText.of(3, 0, TEAM_MODE.merged({"winner_team": 1}, true))["title"], "패배…")
	var timed := ResultText.of(2, 0, _timed(0, [1, -1, 4, 1]))
	assert_eq(timed["title"], "패배…")
	assert_eq(timed["detail"], "P3 4점 · P1 1점 · P4 1점 · P2 -1점")
	assert_eq(ResultText.of(0, 0, {})["detail"], "", "stock: no detail")


func test_banner_shows_the_detail_line() -> void:
	var hud := _hud(4, TEAM_MODE)
	hud.show_result(1, 0)
	assert_eq(hud.banner().title(), "패배…")
	assert_eq(hud.banner().detail(), "팀 2 승리 · P2 · P4")
