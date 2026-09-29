extends GutTest
## Bot-vs-bot coverage (context E11). No golden hash (bot changes must not break it): two runs with
## the same seed must match tick for tick, and a long match must go through ring-outs, a KO and
## the Phase 2 event types. Covers the Phase 1 carry-over "replay never asserts ring-out/KO".

const SEED := 21
const MAX_TICKS := 60 * 60 * 4


static func _run(seed_value: int, ticks: int) -> Dictionary:
	var c := GameConfig.new()
	var w := World.new(c, seed_value)
	var bots: Array[BotController] = [BotController.new(0, c), BotController.new(1, c)]
	var hashes: Array[int] = []
	var seen := {}
	for i: int in ticks:
		var view := w.state_view()
		var inputs: Array[InputFrame] = [bots[0].sample(view), bots[1].sample(view)]
		w.tick(inputs)
		hashes.append(w.state_hash())
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
		if w.match_over:
			seen["match_over"] = true
			break
	return {"hash": hash(hashes), "seen": seen}


func test_bot_match_is_deterministic() -> void:
	assert_eq(_run(SEED, 1800)["hash"], _run(SEED, 1800)["hash"])


## Event types a bot match must go through. Task 18 (bot step 2) extends this list with
## ringout, item_pickup, guard_hit and grab, and adds the KO assertion.
const REQUIRED_EVENTS: Array[String] = ["hit", "item_spawn", "item_land"]


func test_bot_match_covers_required_events() -> void:
	var seen: Dictionary = _run(SEED, MAX_TICKS)["seen"]
	for needed: String in REQUIRED_EVENTS:
		assert_true(seen.has(needed), "%s never happened in a bot match" % needed)
