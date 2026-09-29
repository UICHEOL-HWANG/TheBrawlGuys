extends SceneTree
## Sim cost per tick for a 4-fighter bot match (PRD-NFR-02: <= 2 ms/tick on target mobile).
## Two ground items are placed before timing so item pickup, use and motion are part of the cost.
## Run: godot --headless --path . -s res://scripts/bench_sim.gd

const PLAYERS := 4
const TICKS := 600
const SEED := 3


func _init() -> void:
	var config := GameConfig.new()
	var world := World.new(config, SEED, PLAYERS)
	var bots: Array[BotController] = []
	for i: int in PLAYERS:
		bots.append(BotController.new(i, config))
	world.items.add(Item.Kind.BAT, Vector3(-3.0, 0.0, 0.0), Item.State.GROUND, config)
	world.items.add(Item.Kind.ROCK, Vector3(3.0, 0.0, 0.0), Item.State.GROUND, config)
	var item_events := 0
	var total := 0
	var worst := 0
	for t: int in TICKS:
		var view := world.state_view()
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(view))
		var started := Time.get_ticks_usec()
		world.tick(inputs)
		var cost := Time.get_ticks_usec() - started
		total += cost
		worst = maxi(worst, cost)
		for e: Dictionary in world.state_view()["events"]:
			if String(e["type"]).begins_with("item"):
				item_events += 1
	print("bench_sim: %d fighters, %d ticks, avg %.1f us/tick, worst %d us/tick, %d item events" % [
		PLAYERS, TICKS, float(total) / TICKS, worst, item_events])
	quit(0)
