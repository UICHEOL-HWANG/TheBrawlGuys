extends GutTest
## Each match gets a fresh seed from the app layer (MatchSeed, never inside the sim): bots and the
## match randomness vary between matches, and the seed telemetry records still replays the match.

const BotMatchRun := preload("res://tests/unit/support/bot_match_run.gd")
const TICKS := 600


func test_fresh_seeds_are_positive_and_vary() -> void:
	var seen := {}
	for i: int in 20:
		var s := MatchSeed.fresh()
		assert_between(s, 1, MatchSeed.MAX_SEED, "fits matches.seed and survives JSON")
		seen[s] = true
	assert_gt(seen.size(), 15, "twenty matches, (almost) twenty seeds")


func test_two_setups_from_the_app_get_different_seeds() -> void:
	var app := App.new()
	var a := app.new_setup(MatchSetup.MODE_BOT)
	var b := app.new_setup(MatchSetup.MODE_BOT)
	assert_ne(a.seed, b.seed, "a new seed per match")
	assert_ne(a.seed, MatchSetup.DEFAULT_SEED)
	assert_eq(app.new_setup(MatchSetup.MODE_LOCAL_2P).mode, MatchSetup.MODE_LOCAL_2P)
	assert_null(app.new_setup(MatchSetup.MODE_ONLINE), "online is not playable yet")
	app.free()


func test_bots_are_drawn_from_the_setup_seed() -> void:
	var app := App.new()
	app.new_seed = func() -> int: return 424242
	var setup := app.new_setup(MatchSetup.MODE_BOT)
	assert_eq(setup.seed, 424242)
	setup.assign_characters({0: CharacterData.KNIGHT})
	var taken: Array[String] = [CharacterData.KNIGHT]
	assert_eq(setup.characters()[1], CharacterPicks.for_bots(424242, taken, 1)[0])
	app.free()


func test_the_recorded_seed_replays_the_match() -> void:
	var seed := MatchSeed.fresh()
	var setup := MatchSetup.all_bots(3, seed)
	setup.assign_characters({})
	var picks := {}
	for s: Dictionary in setup.slots:
		picks[int(s["slot"])] = String(s["character"])
	var run := BotMatchRun.play("log_bridge", 3, seed, TICKS, null, picks)
	var export := MatchExport.build(run["telemetry"])
	assert_eq(int(export["match"]["seed"]), seed, "matches.seed holds the fresh seed")
	var sent: Array = run["sent"]
	var ends := ["match_ended", "match_abandoned"]  # a short run ends as abandoned
	var found := {}
	for e: Array in sent:
		if e[0] == "match_started" or ends.has(e[0]):
			found[e[0]] = true
			assert_eq(e[1]["match_id"], export["match"]["id"], "%s joins matches.seed by match_id" % e[0])
	assert_eq(found.size(), 2, "the start and the end event were both sent")
	var result := ReplayVerifier.verify(export, GameConfig.new())
	assert_true(result["ok"], ReplayVerifier.line(result))
	var other := export.duplicate(true)
	other["match"]["seed"] = seed + 1
	assert_false(ReplayVerifier.verify(other, GameConfig.new())["ok"], "the seed matters to the replay")
