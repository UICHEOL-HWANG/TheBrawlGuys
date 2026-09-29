extends GutTest


func test_main_runs_a_match_loop() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.5)
	var w: World = main.call("get_world")
	assert_not_null(w)
	assert_gt(w.tick_count, 0, "fixed ticks advanced")
	assert_eq(w.fighters.size(), 2)
	assert_ne(w.fighters[1].pos, Rules.spawn_point(1, 2, w.config), "the bot moved")


func test_restart_after_a_ko_starts_a_clean_match() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_seconds(0.2)
	var hud: Hud = main.call("get_hud")
	assert_true(hud.result_visible(), "the KO ends the match and shows the result")
	hud.restart_requested.emit()
	await wait_frames(1)
	var fresh: World = main.call("get_world")
	assert_ne(fresh, w, "a new world")
	assert_false(hud.result_visible())
	assert_eq(hud.counter_text(1), "0%")
	assert_lt(fresh.tick_count, 30, "the new match just started")


func test_items_in_the_world_get_views() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.items.add(Item.Kind.BOMB, Vector3(0, 0, 0), Item.State.GROUND, w.config)
	await wait_seconds(0.1)
	var layer: ItemLayer = main.call("get_item_layer")
	assert_eq(layer.view_count(), 1)
