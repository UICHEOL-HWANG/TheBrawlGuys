extends GutTest
## Who cheers before the result banner and where the close shot looks (GD-CAM-02).


func _f(x: float, state: int = Fighter.State.IDLE) -> Dictionary:
	return {"pos": Vector3(x, 0.0, 0.0), "state": state}


func _view(winner: int, fighters: Array, mode: Dictionary = {}) -> Dictionary:
	return {"winner": winner, "fighters": fighters, "mode": mode}


func test_stock_winner_cheers_alone() -> void:
	assert_eq(VictoryCeremony.winners(_view(1, [_f(0), _f(2)])), [1] as Array[int])


func test_draw_has_no_one_to_cheer() -> void:
	assert_eq(VictoryCeremony.winners(_view(Rules.DRAW, [_f(0), _f(2)])), [] as Array[int])


func test_team_win_cheers_the_standing_teammates() -> void:
	var mode := {"rule": MatchRules.TEAM, "teams": [0, 1, 0, 1], "winner_team": 0}
	var fighters := [_f(0), _f(1), _f(4, Fighter.State.KO), _f(3)]
	assert_eq(VictoryCeremony.winners(_view(0, fighters, mode)), [0] as Array[int], "a knocked-out mate sits it out")
	fighters[2] = _f(4)
	assert_eq(VictoryCeremony.winners(_view(0, fighters, mode)), [0, 2] as Array[int])


func test_shot_leads_toward_the_camera_and_eases_in() -> void:
	var v := _view(0, [_f(2), _f(8)])
	var at := VictoryCeremony.focus(v, [0] as Array[int])
	assert_almost_eq(at.x, 2.0, 0.001)
	assert_gt(at.z, 0.0, "led toward the camera so the winner stands above the banner")
	assert_eq(VictoryCeremony.camera_weight(v, [0] as Array[int], 0.0), 0.0)
	assert_almost_eq(VictoryCeremony.camera_weight(v, [0] as Array[int], 5.0), VictoryCeremony.CAMERA_WEIGHT, 0.001)


func test_spread_out_winners_get_a_wider_shot() -> void:
	var near := _view(0, [_f(0), _f(1)])
	var far := _view(0, [_f(0), _f(12)])
	var both := [0, 1] as Array[int]
	assert_gt(VictoryCeremony.camera_weight(near, both, 5.0), VictoryCeremony.camera_weight(far, both, 5.0))
