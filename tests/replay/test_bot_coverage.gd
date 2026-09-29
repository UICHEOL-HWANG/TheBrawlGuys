extends GutTest
## Bot-vs-bot coverage (context E11). No golden hash (bot changes must not break it). Asserts:
## 1. two runs with the same seed produce the same hash sequence (determinism);
## 2. one seed-21 bot match, played to its end, produces every event type in REQUIRED_EVENTS
##    (ring-out, item spawn/land/pickup/throw/drop, guard hit, grab, hit) and a KO (match over);
## 3. restoring a mid-match snapshot into a fresh World and replaying the recorded inputs
##    reproduces the original per-tick state hashes (item-use paths included).
## Covers the Phase 1 carry-over "replay never asserts ring-out/KO".

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


## Event types a bot match must go through (bot step 2, Task 18).
const REQUIRED_EVENTS: Array[String] = ["hit", "ringout", "item_spawn", "item_land", "item_pickup", "guard_hit", "grab",
		"item_throw", "item_drop"]


func test_bot_match_covers_required_events() -> void:
	var seen: Dictionary = _run(SEED, MAX_TICKS)["seen"]
	for needed: String in REQUIRED_EVENTS:
		assert_true(seen.has(needed), "%s never happened in a bot match" % needed)
	assert_true(seen.has("match_over"), "a bot match ends with a KO within 4 minutes")


const SNAPSHOT_EVERY := 150
const RESTORE_TICKS := 300
const RESTORE_EVENTS: Array[String] = ["item_throw", "item_drop", "item_pickup", "grab"]


## Plays the bot match recording every tick's inputs and hash, and a snapshot every SNAPSHOT_EVERY
## ticks (taken before that tick is played).
static func _record(seed_value: int, ticks: int) -> Dictionary:
	var c := GameConfig.new()
	var w := World.new(c, seed_value)
	var bots: Array[BotController] = [BotController.new(0, c), BotController.new(1, c)]
	var inputs_log: Array[Array] = []
	var hashes: Array[int] = []
	var snapshots: Dictionary = {}
	var first_event_tick: Dictionary = {}
	for i: int in ticks:
		if i % SNAPSHOT_EVERY == 0:
			snapshots[i] = w.snapshot()
		var view := w.state_view()
		var inputs: Array[InputFrame] = [bots[0].sample(view), bots[1].sample(view)]
		inputs_log.append(inputs)
		w.tick(inputs)
		hashes.append(w.state_hash())
		for e: Dictionary in w.state_view()["events"]:
			if not first_event_tick.has(e["type"]):
				first_event_tick[e["type"]] = i
		if w.match_over:
			break
	return {"inputs": inputs_log, "hashes": hashes, "snapshots": snapshots, "first_event_tick": first_event_tick}


func test_restore_then_continue_matches_the_original_run() -> void:
	var rec := _record(SEED, MAX_TICKS)
	var inputs_log: Array[Array] = rec["inputs"]
	var hashes: Array[int] = rec["hashes"]
	var snapshots: Dictionary = rec["snapshots"]
	var first_event_tick: Dictionary = rec["first_event_tick"]
	# Restore from the snapshot just before the first throw, drop, pickup and grab, so the replayed
	# window contains each of those paths.
	var starts: Array[int] = []
	for type: String in RESTORE_EVENTS:
		assert_true(first_event_tick.has(type), "%s happens in the recorded match" % type)
		var start := int(first_event_tick.get(type, 0)) / SNAPSHOT_EVERY * SNAPSHOT_EVERY
		if snapshots.has(start) and not starts.has(start):
			starts.append(start)
	assert_gte(starts.size(), 2, "several distinct restore points")
	for start: int in starts:
		var w := World.new(GameConfig.new(), SEED + 1000)  # a different seed: restore must overwrite the RNG
		assert_true(w.restore(snapshots[start]), "restore at tick %d" % start)
		var end := mini(start + RESTORE_TICKS, hashes.size())
		for i: int in range(start, end):
			var inputs: Array[InputFrame] = []
			inputs.assign(inputs_log[i])
			w.tick(inputs)
			var same := w.state_hash() == hashes[i]
			assert_true(same, "tick %d after restoring at %d" % [i, start])
			if not same:
				break
