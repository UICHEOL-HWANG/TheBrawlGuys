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
	var hud: Hud = main.call("get_hud")
	await wait_until(hud.result_visible, 5.0)
	assert_true(hud.result_visible(), "the KO ends the match and shows the result after the replay")
	hud.restart_requested.emit()
	await wait_seconds(DS.MOTION_BASE + 0.1)  # the banner fades out first
	var fresh: World = main.call("get_world")
	assert_ne(fresh, w, "a new world")
	assert_false(hud.result_visible())
	assert_eq(hud.counter_text(1), "0%")
	assert_lt(fresh.tick_count, 30, "the new match just started")


func test_a_ring_out_finish_replays_slowly_before_the_result() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_physics_frames(3)
	var hud: Hud = main.call("get_hud")
	assert_true(w.match_over)
	assert_false(hud.result_visible(), "the finishing replay plays first (GD-CAM-02)")
	assert_lt(Engine.time_scale, 1.0, "slowed while it plays")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await wait_physics_frames(2)
	assert_true(hud.result_visible(), "accept skips to the banner")
	assert_eq(Engine.time_scale, 1.0, "normal speed again")


func test_telemetry_follows_the_match() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var t: MatchTelemetry = main.call("get_telemetry")
	assert_true(t.is_active(), "tracking starts with the match")
	var w: World = main.call("get_world")
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_seconds(0.2)
	assert_false(t.is_active(), "match over ends tracking")
	assert_eq(t.match_row()["result"], "win")
	assert_gt(t.event_rows().size(), 0, "raw rows collected")
	var hud: Hud = main.call("get_hud")
	hud.restart_requested.emit()
	var fresh: MatchTelemetry = main.call("get_telemetry")
	assert_ne(fresh, t)
	assert_ne(fresh.match_id(), t.match_id())
	assert_true(fresh.is_active())


func test_restart_mid_match_abandons_the_old_tracking() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var t: MatchTelemetry = main.call("get_telemetry")
	var hud: Hud = main.call("get_hud")
	hud.restart_requested.emit()
	assert_false(t.is_active())
	assert_eq(t.match_row()["result"], "abandoned")


func test_items_in_the_world_get_views() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.items.add(Item.Kind.BOMB, Vector3(0, 0, 0), Item.State.GROUND, w.config)
	await wait_seconds(0.1)
	var layer: ItemLayer = main.call("get_item_layer")
	assert_eq(layer.view_count(), 1)


func test_restart_clears_item_views_immediately() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var w: World = main.call("get_world")
	w.items.add(Item.Kind.BOMB, Vector3(0, 0, 0), Item.State.GROUND, w.config)
	await wait_seconds(0.1)
	var layer: ItemLayer = main.call("get_item_layer")
	assert_eq(layer.view_count(), 1)
	var hud: Hud = main.call("get_hud")
	hud.restart_requested.emit()
	assert_eq(layer.view_count(), 0, "no stale item view survives a restart")


func test_match_scene_plays_the_given_setup() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var setup := MatchSetup.vs_bots(3, 5)
	main.set("setup", setup)
	main.set("menu_available", true)
	add_child_autofree(main)
	await wait_seconds(0.3)
	var w: World = main.call("get_world")
	assert_eq(w.fighters.size(), 3)
	var hud: Hud = main.call("get_hud")
	for i: int in [1, 2]:
		w.fighters[i].stocks = 1
		w.fighters[i].pos = Vector3(0, w.config.kill_y - 1, 0)
	await wait_until(hud.result_visible, 5.0)  # after the finishing replay
	assert_true(hud.result_visible())
	assert_true(hud.menu_button().visible, "메뉴로 next to 다시 하기")
	watch_signals(main)
	hud.menu_button().pressed.emit()
	assert_signal_emitted(main, "menu_requested")


func test_standalone_match_hides_the_menu_button() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.1)
	var hud: Hud = main.call("get_hud")
	assert_false(hud.menu_button().visible)


func test_perf_match_runs_four_bots() -> void:
	var scene: Node = (load("res://src/debug/perf_match.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_seconds(0.5)
	var w: World = scene.call("get_world")
	assert_eq(w.fighters.size(), 4)
	var moved := 0
	for i: int in 4:
		if w.fighters[i].pos != Rules.spawn_point(i, 4, w.config):
			moved += 1
	assert_eq(moved, 4, "all four fighters are bots")


func test_look_preset_follows_the_config() -> void:
	LookPreset.last_applied = LookPreset.Look.C  # stale value: _ready must overwrite it
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_seconds(0.2)
	var cfg: GameConfig = main.get("_config")
	assert_eq(LookPreset.last_applied, cfg.look_preset, "applied on ready")
	cfg.look_preset = LookPreset.Look.C
	cfg.emit_changed()
	assert_eq(LookPreset.last_applied, LookPreset.Look.C, "the debug-panel Look slider takes effect")
	cfg.look_preset = LookPreset.Look.B
	cfg.emit_changed()
	assert_eq(LookPreset.last_applied, LookPreset.Look.B)
	LookPreset.apply(LookPreset.Look.A)


func _seeded_main(new_seed: Callable) -> Node:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.set("setup", MatchSetup.vs_bots(2, 7))
	if new_seed.is_valid():
		main.set("new_seed", new_seed)
	add_child_autofree(main)
	return main


func test_rematch_draws_a_fresh_seed_from_the_app_source() -> void:
	var next := [100]
	var main := _seeded_main(func() -> int:
		next[0] += 1
		return next[0])
	await wait_process_frames(2)
	var setup: MatchSetup = main.get("setup")
	assert_eq(setup.seed, 7, "the first match plays the seed it was set up with")
	var picks := setup.characters()
	(main.call("get_hud") as Hud).restart_requested.emit()
	assert_eq(setup.seed, 101, "a rematch gets a new seed")
	assert_eq(setup.characters(), picks, "and keeps the line-up")
	(main.call("get_hud") as Hud).restart_requested.emit()
	assert_eq(setup.seed, 102)


func test_rematch_keeps_the_seed_without_a_source() -> void:
	var main := _seeded_main(Callable())
	await wait_process_frames(2)
	(main.call("get_hud") as Hud).restart_requested.emit()
	assert_eq((main.get("setup") as MatchSetup).seed, 7, "perf, debug and main.tscn alone stay fixed")
