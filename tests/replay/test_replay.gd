extends GutTest
## Replay regression (context D3): seed + config + scripted inputs -> state_hash sequence.
## GOLDEN_HASH guards against unintended sim changes. When a sim change is deliberate,
## re-run this file, copy the printed value into GOLDEN_HASH and say why in the commit message.
## The golden value is tied to the Godot version (4.7.2) because it hashes engine floats.

const SEED := 7
const TICKS := 1200
const HALF := 600
const GOLDEN_HASH := 4141742054
## Sim behavior without the config fingerprint (context F1). Changes only with deliberate sim
## changes, each explained in its commit message (Phase 4: snapshot v5 arena/burn fields, then
## the carried-over combat fixes; Phase 5: snapshot v6 adds fighter character/gauge and the
## projectile field — test_classic_compat proves the classic behaviour itself is unchanged;
## combat-depth A: P1's guard presses with a move input now roll, guards drain the guard meter and
## early guards are perfect guards, snapshot v7 adds the defense fields; defense review: guard
## presses made during hitstun/hitstop are buffered into rolls, snapshot v8).
## Presentation work must never move it.
const BEHAVIOR_HASH := 3016412774


## P0 walks back and forth with jumps, light presses, a held heavy every 4 s and grab presses;
## P1 walks at P0 with light presses, guards in bursts and grabs now and then. Deterministic
## functions of t only (no bot), so the golden hash guards the sim alone (context E11).
static func _script_input(player: int, t: int) -> InputFrame:
	if player == 0:
		var mx := 1.0 if floori(t / 150.0) % 2 == 0 else -1.0
		var heavy := t % 240 >= 100 and t % 240 < 130
		return InputFrame.make(mx, 0.0, t % 45 == 0, t % 20 == 10, heavy, false, t % 61 == 50)
	var mz := -0.1 if floori(t / 70.0) % 2 == 0 else 0.1
	var guard := t % 180 >= 120 and t % 180 < 150
	return InputFrame.make(-1.0, mz, t % 60 == 30, t % 25 == 5, false, guard, t % 107 == 70)


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


func test_the_script_exercises_phase_2_actions() -> void:
	var w := World.new(GameConfig.new(), SEED)
	var seen := {}
	for i: int in TICKS:
		w.tick(_inputs_at(w.tick_count))
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
			if e["type"] == "hit" and e.has("attack_kind"):
				seen["kind_%d" % int(e["attack_kind"])] = true
	for needed: String in ["hit", "item_spawn", "item_land"]:
		assert_true(seen.has(needed), "%s must happen, or the golden hash guards nothing" % needed)
	assert_true(seen.has("kind_%d" % AttackSet.Kind.LIGHT_1), "light combo exercised")
	assert_true(seen.has("guard_hit") or seen.has("kind_%d" % AttackSet.Kind.HEAVY) or seen.has("grab"),
			"at least one of guard, heavy or grab lands")


func test_config_changes_the_run() -> void:
	var other := GameConfig.new()
	other.move_speed = 6.5
	assert_ne(_run(World.new(other, SEED), TICKS), _run(World.new(GameConfig.new(), SEED), TICKS))


func test_golden_hash() -> void:
	var h := _run(World.new(GameConfig.new(), SEED), TICKS)
	assert_ne(GOLDEN_HASH, 0, "GOLDEN_HASH not set yet; set it to %d" % h)
	assert_eq(h, GOLDEN_HASH, "sim behavior changed; if deliberate, update GOLDEN_HASH to %d" % h)


## Hash of each tick's snapshot with config_fp removed, so tuning outside the sim cannot move it.
static func _behavior_run(w: World, ticks: int) -> int:
	var seq: Array[int] = []
	for i: int in ticks:
		w.tick(_inputs_at(w.tick_count))
		var s: Dictionary = bytes_to_var(w.snapshot())
		s.erase("config_fp")
		seq.append(hash(s))
	return hash(seq)


func test_behavior_hash() -> void:
	var h := _behavior_run(World.new(GameConfig.new(), SEED), TICKS)
	assert_ne(BEHAVIOR_HASH, 0, "BEHAVIOR_HASH not set yet; set it to %d" % h)
	assert_eq(h, BEHAVIOR_HASH, "sim behavior changed; if deliberate, update BEHAVIOR_HASH to %d" % h)
