extends GutTest
## Team select (2v2): P1's teammate is P2, P3 (the default) or P4, so both teams always have two;
## arrows / stick move, Z / Enter confirm, Esc goes back, a tap picks; tracked as team_selected /
## select_cancelled. Captions say who is a human and who is a bot.

var _tracked: Array = []
var _chosen: Array = []


func _setup(local_2p: bool = false) -> MatchSetup:
	var s := MatchSetup.local_versus(2, 1) if local_2p else MatchSetup.vs_bots(2, 1)
	s.set_rule(MatchRules.TEAM)
	return s


func _screen(setup: MatchSetup = null) -> TeamSelectScreen:
	_tracked.clear()
	_chosen.clear()
	var s := TeamSelectScreen.new()
	s.setup = setup if setup != null else _setup()
	s.track = func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, n)
		_tracked.append([n, p])
	s.teams_chosen.connect(func(t: Array[int]) -> void: _chosen.append(t))
	add_child_autofree(s)
	return s


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func test_options_cover_every_two_vs_two_split() -> void:
	var entries := TeamOptions.entries(_setup())
	assert_eq(entries.map(func(e: Dictionary) -> String: return e["id"]), ["12", "13", "14"])
	assert_eq(entries.map(func(e: Dictionary) -> String: return e["title"]),
			["P1·P2 대 P3·P4", "P1·P3 대 P2·P4", "P1·P4 대 P2·P3"])
	assert_eq(TeamOptions.teams_of("12"), [0, 0, 1, 1] as Array[int])
	assert_eq(TeamOptions.teams_of("13"), MatchRules.default_teams(4))
	assert_eq(TeamOptions.teams_of("14"), [0, 1, 1, 0] as Array[int])
	for e: Dictionary in entries:
		assert_true(MatchRules.is_two_vs_two(TeamOptions.teams_of(String(e["id"]))))
	assert_eq(TeamOptions.id_of([0, 1, 1, 0] as Array[int]), "14")


func test_captions_name_humans_and_bots() -> void:
	assert_eq(TeamOptions.entries(_setup())[0]["caption"], "나 + 봇 대 봇 + 봇")
	var two := TeamOptions.entries(_setup(true))
	assert_eq(two[0]["caption"], "P1 + P2 대 봇 + 봇", "local 2P: humans together")
	assert_eq(two[1]["caption"], "P1 + 봇 대 P2 + 봇", "or on opposite sides")


func test_starts_on_the_default_split_and_confirms_with_keys() -> void:
	var s := _screen()
	await wait_process_frames(1)
	assert_eq(s.option_ids()[s.focus_index()], TeamOptions.DEFAULT_ID, "P1·P3 vs P2·P4 first")
	s._input(_key(KEY_LEFT))
	s._input(_key(KEY_Z))
	assert_eq(_chosen, [[0, 0, 1, 1]])
	assert_eq(_tracked.back()[0], "team_selected")
	var props: Dictionary = _tracked.back()[1]
	assert_eq(props["pairing"], "12")
	assert_eq(props["teams"], [0, 0, 1, 1])
	assert_eq(int(props["browse_count"]), 1)
	assert_eq(props["focused"], ["13", "12"] as Array[String], "the default first")


func test_shows_the_setup_split_when_revisited() -> void:
	var setup := _setup()
	setup.set_teams(TeamOptions.teams_of("14"))
	var s := _screen(setup)
	await wait_process_frames(1)
	assert_eq(s.option_ids()[s.focus_index()], "14")


func test_tap_picks_and_escape_goes_back() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s.buttons()[2].pressed.emit()
	assert_eq(_chosen, [[0, 1, 1, 0]])
	var other := _screen()
	await wait_process_frames(1)
	var left := [false]
	other.cancelled.connect(func() -> void: left[0] = true)
	other._input(_key(KEY_ESCAPE))
	assert_true(left[0])
	assert_eq(_tracked.back()[0], "select_cancelled")
	assert_eq(_tracked.back()[1]["screen"], "team")
	assert_true(_chosen.is_empty())
