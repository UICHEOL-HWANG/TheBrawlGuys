extends GutTest
## Phase 5 T1 rule "no character = the Phase 4 fighter": the golden replay script (test_replay)
## hashed with the Phase 5 snapshot additions stripped back to the v5 shape (no projectiles, no
## fighter character / gauge, v = 5, no config fingerprint) must still equal the last Phase 4
## BEHAVIOR_HASH. So adding styles and specials moved no classic fighter by a single bit.
## Combat-depth A deliberately changed every fighter (rolls, guard meter, perfect guard), so the
## constant was re-recorded then (Phase 4 value 11665018) with the v7 defense fields stripped too,
## and again for the defense review's buffered rolls (previous value 2661913497). Combat-depth D
## (match modes, v9) only adds the "mode" state and fighter ally_mask: stripped here, the stock
## run is bit-identical.

const R := preload("res://tests/replay/test_replay.gd")
const DEFENSE_FIELDS: Array[String] = [
	"guard_prev", "guard_press_age", "guard_rest_ticks", "guard_hp", "guard_idle_ticks", "guard_break_left",
	"perfect_by",
	"dodge_kind", "dodge_ticks", "dodge_total", "dodge_dir", "intangible", "air_dodge_used",
	"roll_streak", "roll_recent",
]
const PHASE_4_BEHAVIOR_HASH := 3799200070
const PHASE_4_SNAPSHOT_VERSION := 5


func test_classic_fighters_behave_exactly_like_phase_4() -> void:
	var w := World.new(GameConfig.new(), R.SEED)
	var seq: Array[int] = []
	for i: int in R.TICKS:
		w.tick(R._inputs_at(w.tick_count))
		var s: Dictionary = bytes_to_var(w.snapshot())
		s.erase("config_fp")
		s.erase("projectiles")
		s.erase("mode")
		s["v"] = PHASE_4_SNAPSHOT_VERSION
		for f: Dictionary in s["fighters"]:
			f.erase("character")
			f.erase("gauge")
			f.erase("ally_mask")
			for key: String in DEFENSE_FIELDS:
				f.erase(key)
		seq.append(hash(s))
	assert_eq(hash(seq), PHASE_4_BEHAVIOR_HASH)
