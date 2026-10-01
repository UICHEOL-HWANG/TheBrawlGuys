extends GutTest
## The HUD strip (DS-LAY-02 v2, combat-depth D): PlayerCards along the bottom, P1 + P3 on the left
## and P2 + P4 mirrored on the right; team mode heads each group "팀 1" / "팀 2"; timed shows the
## clock between the groups and scores for stock pips (red final 10 s); touch moves the strip up;
## the camera reserve follows the strip; combo badges; result wording per rule.

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
		out.append({"id": i, "damage": 10.0 * i, "stocks": 3, "state": Fighter.State.IDLE, "special": "",
			"gauge": 0.0})
	return out


func _timed(ticks_left: int, scores: Array, sudden: bool = false) -> Dictionary:
	return {"rule": "timed", "teams": [], "scores": scores, "ticks_left": ticks_left, "sudden_death": sudden,
		"winner_team": -1}


func test_cards_sit_along_the_bottom_odd_slots_right() -> void:
	var hud := _hud(4, {})
	await wait_process_frames(2)
	var cards := hud.strip().cards
	var vp := hud.get_viewport().get_visible_rect()
	for c: PlayerCard in cards:
		assert_gt(c.get_global_rect().position.y, vp.size.y * 0.5, "bottom half")
	assert_lt(cards[0].get_global_rect().position.x, vp.size.x * 0.5, "P1 left")
	assert_lt(cards[2].get_global_rect().position.x, vp.size.x * 0.5, "P3 left")
	assert_gt(cards[1].get_global_rect().position.x, vp.size.x * 0.5, "P2 right")
	assert_gt(cards[3].get_global_rect().position.x, vp.size.x * 0.5, "P4 right")
	assert_false(cards[0].get_global_rect().intersects(cards[2].get_global_rect()))
	assert_eq(hud.frame_margin("bottom"), DS.S5)


func test_team_groups_have_headers_and_keep_teammates_together() -> void:
	var hud := _hud(4, {"rule": "team", "teams": [0, 0, 1, 1]})
	await wait_process_frames(2)
	var strip := hud.strip()
	assert_eq(strip.headers.map(func(l: Label) -> String: return l.text), ["팀 1", "팀 2"])
	var mid := hud.get_viewport().get_visible_rect().size.x * 0.5
	assert_lt(strip.cards[1].get_global_rect().position.x, mid, "teams decide the side, not the slot")
	assert_gt(strip.cards[2].get_global_rect().position.x, mid)


func test_cards_show_damage_stocks_and_the_gauge() -> void:
	var hud := _hud(2, {})
	var fighters := _fighters(2)
	fighters[1].merge({"damage": 41.6, "stocks": 1, "special": "spin_slash", "gauge": SpecialGauge.MAX}, true)
	hud.update_from({"tick": 1, "fighters": fighters, "mode": {}})
	assert_eq(hud.counter_text(1), "42%")
	assert_eq(hud.stocks_shown(1), 1)
	assert_true(hud.strip().cards[1].gauge_bar().is_flashing(), "full gauge flashes")
	assert_false(hud.strip().cards[0].gauge_bar().is_flashing())


func test_timed_shows_the_clock_and_scores() -> void:
	var hud := _hud(4, _timed(SimTime.to_ticks(120.0), [0, 0, 0, 0]))
	hud.update_from({"tick": 1, "fighters": _fighters(4), "mode": _timed(SimTime.to_ticks(95.0), [2, -1, 0, 0])})
	var strip := hud.strip()
	assert_eq(strip.timer.text(), "1:35")
	assert_false(strip.timer.is_final())
	assert_eq(strip.cards[0].score_text(), "2점")
	assert_eq(strip.cards[1].score_text(), "-1점")
	assert_eq(strip.cards[0].stocks_shown(), 0, "scores replace stock pips")
	hud.update_from({"tick": 2, "fighters": _fighters(4), "mode": _timed(SimTime.to_ticks(9.5), [0, 0, 0, 0])})
	assert_eq(strip.timer.text(), "0:10")
	assert_true(strip.timer.is_final())
	hud.update_from({"tick": 3, "fighters": _fighters(4), "mode": _timed(0, [1, 1, 0, 0], true)})
	assert_eq(strip.timer.text(), MatchTimer.SUDDEN_DEATH_TEXT)


func test_stock_has_no_clock_or_headers() -> void:
	var hud := _hud(2, {})
	assert_null(hud.strip().timer)
	assert_true(hud.strip().headers.is_empty())


func test_touch_moves_the_strip_to_the_top_and_the_camera_follows() -> void:
	var hud := _hud(2, {})
	await wait_process_frames(2)
	var bottom := hud.reserve()
	assert_gt(float(bottom["bottom"]), 0.05)
	assert_eq(float(bottom["top"]), 0.0)
	var touch := [true]
	hud.show_key_hints([{"prefix": "p1", "slot": 0, "accent": DS.P1}] as Array[Dictionary],
			func() -> bool: return touch[0])
	await wait_process_frames(2)
	assert_true(hud.strip().is_edge_top())
	assert_lt(hud.strip().cards[0].get_global_rect().end.y, hud.get_viewport().get_visible_rect().size.y * 0.5)
	assert_gt(float(hud.reserve()["top"]), 0.05)
	assert_eq(float(hud.reserve()["bottom"]), 0.0)


func test_combo_badge_counts_hits_on_one_target() -> void:
	var hud := _hud(2, {})
	var hit := {"type": "hit", "attacker": 0, "target": 1}
	for t: int in [10, 20, 30]:
		hud.update_from({"tick": t, "fighters": _fighters(2), "mode": {}}, [hit])
	assert_eq(hud.strip().cards[0].combo_text(), "3연타")
	hud.update_from({"tick": 200, "fighters": _fighters(2), "mode": {}}, [{"type": "jumped"}])
	assert_eq(hud.strip().cards[0].combo_text(), "", "the run ends after the window")


func test_combo_tracker_rules() -> void:
	var c := ComboTracker.new()
	c.on_events([{"type": "hit", "attacker": 1, "target": 0}], 0)
	c.on_events([{"type": "hit", "attacker": 1, "target": 0}], 30)
	assert_eq(c.count(1, 30), 2)
	c.on_events([{"type": "hit", "attacker": 1, "target": 2}], 40)
	assert_eq(c.count(1, 40), 1, "another target starts over")
	c.on_events([{"type": "guard_hit", "attacker": 1, "target": 2}], 50)
	assert_eq(c.count(1, 50), 0, "a guarded hit breaks it")
	c.on_events([{"type": "hit", "attacker": 1, "target": 2}], 60)
	assert_eq(c.count(1, 60 + ComboTracker.WINDOW_TICKS + 1), 0)


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


func test_hud_safe_frame_math() -> void:
	var none := HudSafeFrame.fit(40.0, 1.6, 0.0, 0.0)
	assert_almost_eq(float(none["fov"]), 40.0, 0.001)
	assert_eq(float(none["shift"]), 0.0)
	var bottom := HudSafeFrame.fit(40.0, 1.6, 0.0, 0.25)
	assert_lt(float(bottom["fov"]), 40.0, "the fight is fitted into the band above the strip")
	assert_almost_eq(float(bottom["aspect"]), 1.6 / 0.75, 0.0001)
	assert_almost_eq(float(bottom["shift"]), -0.25, 0.0001, "window shifted down for a bottom strip")
	var capped := HudSafeFrame.fit(40.0, 1.6, 0.4, 0.4)
	assert_almost_eq(float(capped["aspect"]), 1.6 / (1.0 - HudSafeFrame.MAX_SHARE), 0.0001)


func test_frames_without_a_tick_do_not_recount_hits() -> void:
	var hud := _hud(2, {})
	var hit := {"type": "hit", "attacker": 0, "target": 1}
	for t: int in [10, 20]:
		hud.update_from({"tick": t, "fighters": _fighters(2), "mode": {}, "events": [hit]}, [hit])
	for i: int in 3:
		hud.update_from({"tick": 20, "fighters": _fighters(2), "mode": {}, "events": [hit]})
	assert_eq(hud.strip().cards[0].combo_text(), "2연타", "render frames with no sim tick add nothing")
