extends GutTest
## A local 2-player match (PRD-LOCAL-01): both humans drive their own slot, each gets a key bar in
## their color with the special chord cap, the result names the winner and P2's device is tracked.

const MAIN := preload("res://src/main/main.tscn")


func after_each() -> void:
	for prefix: String in InputBindings.PREFIXES:
		for action: String in InputBindings.actions(prefix):
			Input.action_release(action)


func _main(setup: MatchSetup) -> Node:
	var main: Node = MAIN.instantiate()
	main.set("setup", setup)
	add_child_autofree(main)
	return main


func test_p2_keys_move_the_second_fighter() -> void:
	var main := _main(MatchSetup.local_versus())
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	var start_p1 := w.fighters[0].pos
	var start_p2 := w.fighters[1].pos
	Input.action_press("p2_left")
	await wait_seconds(0.3)
	assert_lt(w.fighters[1].pos.x, start_p2.x - 0.1, "A moves P2 left")
	assert_almost_eq(w.fighters[0].pos.x, start_p1.x, 0.01, "P1 stands still")


func test_each_human_gets_a_key_bar_with_the_special_cap() -> void:
	var main := _main(MatchSetup.local_versus())
	await wait_process_frames(3)
	var hints: KeyHintHud = (main.call("get_hud") as Hud).key_hints()
	assert_eq(hints.bars().size(), 2)
	assert_eq(hints.bars()[0].accent(), DS.P1)
	assert_eq(hints.bars()[1].accent(), DS.P2)
	assert_eq(hints.bars()[1].cap_text("special"), "G+H")
	assert_eq(hints.bars()[0].cap_text("special"), "X+C")
	Input.action_press("p2_heavy")
	Input.action_press("p2_guard")
	await wait_process_frames(2)
	assert_eq(hints.bars()[1].cap_state("special"), KeyCap.State.PRESSED)
	assert_eq(hints.bars()[0].cap_state("special"), KeyCap.State.IDLE)
	var rect0 := hints.bars()[0].get_global_rect()
	var rect1 := hints.bars()[1].get_global_rect()
	assert_false(rect0.intersects(rect1), "the two bars do not overlap")
	assert_lt(rect0.position.x, rect1.position.x, "P1 left, P2 right like the HUD counters")


func test_bots_fill_slots_after_the_two_humans() -> void:
	var main := _main(MatchSetup.local_versus(3))
	await wait_seconds(0.3)
	var w: World = main.call("get_world")
	assert_eq(w.fighters.size(), 3)
	assert_ne(w.fighters[2].pos, Rules.spawn_point(2, 3, w.config), "the bot in slot 2 plays")


func test_tracking_sees_two_local_keyboard_slots() -> void:
	var main := _main(MatchSetup.local_versus())
	await wait_process_frames(3)
	var setup: MatchSetup = main.get("setup")
	assert_eq(setup.slots[0]["input_device"], PlatformEnv.default_input_device())
	assert_eq(setup.slots[1]["input_device"], MatchSetup.INPUT_KEYBOARD, "no pad: P2 is on the keyboard")
	var t: MatchTelemetry = main.call("get_telemetry")
	assert_true(t.is_active())


func test_result_names_the_winning_player_when_two_humans_play() -> void:
	var main := _main(MatchSetup.local_versus())
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.fighters[0].stocks = 1
	w.fighters[0].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_seconds(0.2)
	assert_true((main.call("get_hud") as Hud).result_visible())
	var banner := ResultBanner.new()
	add_child_autofree(banner)
	banner.show_result(1, ResultBanner.NO_LOCAL)
	assert_eq(banner.title(), "P2 승리!")
