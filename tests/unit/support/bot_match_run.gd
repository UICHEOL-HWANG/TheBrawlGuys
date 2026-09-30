extends RefCounted
## Test helper: plays an all-bot match headlessly the way the match scene does (bots read the last
## state view, MatchTelemetry gets every tick's events, view and inputs) and ends tracking with the
## World's final state hash. Returns {"world": World, "telemetry": MatchTelemetry, "sent": Array}.


## config: the sim tuning (default GameConfig.new()).
static func play(arena_id: String, players: int, seed: int, max_ticks: int, config: GameConfig = null) -> Dictionary:
	if config == null:
		config = GameConfig.new()
	var setup := MatchSetup.all_bots(players, seed)
	setup.arena_id = arena_id
	var world := World.new(config, seed, players, setup.build_arena(config))
	var sent: Array = []
	var telemetry := MatchTelemetry.new(func(n: String, p: Dictionary) -> void: sent.append([n, p]))
	telemetry.begin(TelemetrySetup.from_match_setup(setup, config, {"session_id": 1, "user_match_seq": 1}))
	var bots: Array[BotController] = []
	for i: int in players:
		bots.append(BotController.new(i, config))
	var prev := world.state_view()
	while not world.match_over and world.tick_count < max_ticks:
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(prev))
		world.tick(inputs)
		var view := world.state_view()
		var view_events := ViewEvents.detect(prev["fighters"], view["fighters"], config)
		telemetry.on_frame(view["events"], view_events, view, inputs)
		prev = view
	telemetry.end(prev, not world.match_over, world.state_hash())
	return {"world": world, "telemetry": telemetry, "sent": sent}
