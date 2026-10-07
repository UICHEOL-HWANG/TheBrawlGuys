extends GutTest
## MatchSetup teams (team 2v2 select): the chosen split reaches the sim rules, survives copy(),
## is validated as two vs two, and resets when the rule is picked again.

func test_chosen_teams_reach_the_rules_and_survive_copy() -> void:
	var s := MatchSetup.local_versus(2, 1)
	s.set_rule(MatchRules.TEAM)
	assert_eq(s.team_split(), [0, 1, 0, 1] as Array[int], "default P1·P3 vs P2·P4")
	s.set_teams([0, 0, 1, 1] as Array[int])
	assert_true(s.validate().is_empty(), str(s.validate()))
	var c := s.copy()
	assert_eq(c.team_split(), [0, 0, 1, 1] as Array[int])
	c.set_teams([0, 1, 1, 0] as Array[int])
	assert_eq(s.team_split(), [0, 0, 1, 1] as Array[int], "the copy is independent")
	var rules := s.build_rules(GameConfig.new())
	assert_eq(rules.teams, [0, 0, 1, 1] as Array[int])
	assert_eq(s.build_world(GameConfig.new()).fighters[0].ally_mask, 1 << 1, "P2 is P1's teammate in the sim")


func test_validate_rejects_uneven_or_misplaced_teams() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	s.set_rule(MatchRules.TEAM)
	s.set_teams([0, 0, 0, 1] as Array[int])
	assert_string_contains(s.validate()[0], "teams")
	s.set_teams([0, 1] as Array[int])
	assert_string_contains(s.validate()[0], "teams")
	s.set_teams([0, 1, 1, 0] as Array[int])
	assert_true(s.validate().is_empty())
	s.rule = MatchRules.STOCK
	assert_string_contains(s.validate()[0], "teams", "teams only belong to the team rule")


func test_picking_a_rule_again_resets_the_teams() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	s.set_rule(MatchRules.TEAM)
	s.set_teams([0, 0, 1, 1] as Array[int])
	s.set_rule(MatchRules.STOCK)
	assert_true(s.validate().is_empty(), str(s.validate()))
	s.set_rule(MatchRules.TEAM)
	assert_eq(s.team_split(), [0, 1, 0, 1] as Array[int])
