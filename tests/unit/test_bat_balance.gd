extends GutTest
## Phase 3 carry-over: the bat's slow startup lost every exchange against a light attack. A bat
## swung on the same tick as a light attack must connect (a trade at worst), and it keeps its
## longer reach.


## P0 holds a bat, P1 is empty-handed, `gap` apart and facing each other; both press light on
## the same tick, then idle for 20 ticks.
func _bat_vs_light(gap: float) -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].pos = Vector3(-gap * 0.5, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = w.config.bat_uses
	w.fighters[1].pos = Vector3(gap * 0.5, 0, 0)
	w.fighters[1].facing = Vector3(-1, 0, 0)
	var light := InputFrame.make(0, 0, false, true)
	var both: Array[InputFrame] = [light, light]
	w.tick(both)
	for i: int in 20:
		var none: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
		w.tick(none)
	return w


func test_bat_swung_with_a_light_attack_still_lands() -> void:
	var w := _bat_vs_light(1.2)
	assert_eq(w.fighters[1].damage, w.config.bat_damage, "the bat connects instead of being interrupted")


func test_bat_outranges_the_light_attack() -> void:
	var w := _bat_vs_light(2.0)
	assert_eq(w.fighters[1].damage, w.config.bat_damage)
	assert_eq(w.fighters[0].damage, 0.0, "light is out of range")


func test_bat_starts_no_slower_than_the_light_attack() -> void:
	var c := GameConfig.new()
	assert_true(c.bat_startup_ticks <= c.light_startup_ticks)
	var set := AttackSet.from_config(c)
	assert_gt(set.get_attack(AttackSet.Kind.BAT).total_ticks(), set.get_attack(AttackSet.Kind.LIGHT_1).total_ticks(),
			"paid for with a longer recovery")
