extends GutTest


func test_strong_hit_at_100_percent_rings_out() -> void:
	assert_true(FeelScenario.rings_out(GameConfig.new(), 100.0),
			"PHASES Phase 1: at 100%+ one light attack must send the target out")


func test_same_hit_at_0_percent_stays_on_stage() -> void:
	assert_false(FeelScenario.rings_out(GameConfig.new(), 0.0), "knockback must scale with damage")
