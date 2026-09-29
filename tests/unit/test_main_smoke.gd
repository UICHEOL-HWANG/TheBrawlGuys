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
