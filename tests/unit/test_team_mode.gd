extends GutTest
## Team 2v2 (MatchRules.TEAM): teammates' hits pass through with friendly fire off (melee,
## projectiles and items share Fighter.untouchable_by), land with it on, and the match ends when
## only one team still has fighters with stocks.


func _neutral(n: int) -> Array[InputFrame]:
	var a: Array[InputFrame] = []
	for i: int in n:
		a.append(InputFrame.neutral())
	return a


func _world(ff: bool) -> World:
	var rules := MatchRules.team([0, 1, 0, 1] as Array[int], ff)
	var w := World.new(GameConfig.new(), 1, 4, null, [], rules)
	for i: int in 4:
		w.fighters[i].pos = Vector3(-6.0 + 4.0 * i, 0, 6)
	return w


## P1 (team 0) swings at a fighter placed right in front of it; true when that fighter took damage.
func _p1_hits(w: World, target: int) -> bool:
	w.fighters[0].pos = Vector3(0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[target].pos = Vector3(0.9, 0, 0)
	var inputs := _neutral(4)
	inputs[0] = InputFrame.make(0, 0, false, true)
	w.tick(inputs)
	for t: int in 20:
		w.tick(_neutral(4))
	return w.fighters[target].damage > 0.0


func test_ally_mask_is_set_per_fighter() -> void:
	var w := _world(false)
	assert_eq(w.fighters[0].ally_mask, 1 << 2)
	assert_true(w.fighters[2].untouchable_by(0))
	assert_false(w.fighters[1].untouchable_by(0))
	assert_false(w.fighters[2].untouchable_by(-1), "ownerless sources still hit")


func test_teammate_melee_passes_through_with_friendly_fire_off() -> void:
	assert_false(_p1_hits(_world(false), 2))


func test_enemy_melee_still_hits() -> void:
	assert_true(_p1_hits(_world(false), 1))


func test_friendly_fire_on_hits_teammates() -> void:
	assert_true(_p1_hits(_world(true), 2))


func test_team_with_fighters_left_wins() -> void:
	var w := _world(false)
	for id: int in [1, 3]:
		w.fighters[id].stocks = 1
		w.fighters[id].pos = Vector3(0, w.config.kill_y - 1, 0)
		w.fighters[id].on_ground = false
	w.fighters[0].stocks = 1
	w.fighters[0].pos = Vector3(-4, w.config.kill_y - 1, 0)
	w.fighters[0].on_ground = false
	w.tick(_neutral(4))
	assert_true(w.match_over)
	assert_eq(w.mode_state.winner_team, 0)
	assert_eq(w.winner_id, 2, "the surviving teammate is the winner id")
	assert_eq(int(w.state_view()["mode"]["winner_team"]), 0)


func test_match_goes_on_while_both_teams_have_fighters() -> void:
	var w := _world(false)
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.fighters[1].on_ground = false
	w.tick(_neutral(4))
	assert_false(w.match_over)


func test_view_reports_teams() -> void:
	var m: Dictionary = _world(false).state_view()["mode"]
	assert_eq(m["rule"], MatchRules.TEAM)
	assert_eq(m["teams"], [0, 1, 0, 1])
