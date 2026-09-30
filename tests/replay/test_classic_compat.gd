extends GutTest
## Phase 5 T1 rule "no character = the Phase 4 fighter": the golden replay script (test_replay)
## hashed with the Phase 5 snapshot additions stripped back to the v5 shape (no projectiles, no
## fighter character / gauge, v = 5, no config fingerprint) must still equal the last Phase 4
## BEHAVIOR_HASH. So adding styles and specials moved no classic fighter by a single bit.

const R := preload("res://tests/replay/test_replay.gd")
const PHASE_4_BEHAVIOR_HASH := 11665018
const PHASE_4_SNAPSHOT_VERSION := 5


func test_classic_fighters_behave_exactly_like_phase_4() -> void:
	var w := World.new(GameConfig.new(), R.SEED)
	var seq: Array[int] = []
	for i: int in R.TICKS:
		w.tick(R._inputs_at(w.tick_count))
		var s: Dictionary = bytes_to_var(w.snapshot())
		s.erase("config_fp")
		s.erase("projectiles")
		s["v"] = PHASE_4_SNAPSHOT_VERSION
		for f: Dictionary in s["fighters"]:
			f.erase("character")
			f.erase("gauge")
		seq.append(hash(s))
	assert_eq(hash(seq), PHASE_4_BEHAVIOR_HASH)
