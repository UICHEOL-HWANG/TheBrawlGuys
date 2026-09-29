extends GutTest
## Replay regression (context D3): seed + config + scripted inputs -> state_hash sequence.
## GOLDEN_HASH guards against unintended sim changes. When a sim change is deliberate,
## re-run this file, copy the printed value into GOLDEN_HASH and say why in the commit message.
## The golden value is tied to the Godot version (4.7.2) because it hashes engine floats.

const SEED := 7
const TICKS := 600
const HALF := 300
const GOLDEN_HASH := 2898842436


static func _script_input(player: int, t: int) -> InputFrame:
	if player == 0:
		var mx := 1.0 if floori(t / 150.0) % 2 == 0 else -1.0
		return InputFrame.make(mx, 0.0, t % 45 == 0, t % 20 == 10)
	var mz := -0.1 if floori(t / 70.0) % 2 == 0 else 0.1
	return InputFrame.make(-1.0, mz, t % 60 == 30, t % 25 == 5)


static func _inputs_at(t: int) -> Array[InputFrame]:
	var a: Array[InputFrame] = [_script_input(0, t), _script_input(1, t)]
	return a


## Runs `ticks` ticks from the world's current tick and returns a hash of the per-tick state hashes.
static func _run(w: World, ticks: int) -> int:
	var seq: Array[int] = []
	for i: int in ticks:
		w.tick(_inputs_at(w.tick_count))
		seq.append(w.state_hash())
	return hash(seq)


func test_same_inputs_give_identical_runs() -> void:
	var a := _run(World.new(GameConfig.new(), SEED), TICKS)
	var b := _run(World.new(GameConfig.new(), SEED), TICKS)
	assert_eq(a, b)


func test_restore_then_continue_matches_uninterrupted_run() -> void:
	var config := GameConfig.new()
	var straight := World.new(config, SEED)
	_run(straight, HALF)
	var snap := straight.snapshot()
	var second_half_straight := _run(straight, TICKS - HALF)
	var resumed := World.new(config, SEED)
	assert_true(resumed.restore(snap))
	assert_eq(_run(resumed, TICKS - HALF), second_half_straight)


func test_the_script_actually_fights() -> void:
	var w := World.new(GameConfig.new(), SEED)
	var hits := 0
	for i: int in TICKS:
		w.tick(_inputs_at(w.tick_count))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hits += 1
	assert_gt(hits, 0, "the scripted inputs must exercise combat, or the golden hash guards nothing")


func test_config_changes_the_run() -> void:
	var other := GameConfig.new()
	other.move_speed = 6.5
	assert_ne(_run(World.new(other, SEED), TICKS), _run(World.new(GameConfig.new(), SEED), TICKS))


func test_golden_hash() -> void:
	var h := _run(World.new(GameConfig.new(), SEED), TICKS)
	assert_ne(GOLDEN_HASH, 0, "GOLDEN_HASH not set yet; set it to %d" % h)
	assert_eq(h, GOLDEN_HASH, "sim behavior changed; if deliberate, update GOLDEN_HASH to %d" % h)
