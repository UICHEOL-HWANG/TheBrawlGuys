extends GutTest
## Phase 5 T5 (PRD-BOT-02): bots read their style from the view — melee swing range follows the
## style's reach, ranged bots keep their distance, aim and shoot, and a full gauge fires the
## special once a foe is inside its reach.


## Bot 1 at me_pos (style of `character`, facing me_facing) and a classic foe (id 0) at foe_pos.
func _view(character: String, me_pos: Vector3, foe_pos: Vector3, me_facing: Vector3 = Vector3(-1, 0, 0),
		gauge: float = 0.0) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"items": [],
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0},
			{"id": 1, "pos": me_pos, "facing": me_facing, "state": Fighter.State.IDLE, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0,
				"style": CharacterData.style_of(character), "special": CharacterData.special_of(character),
				"gauge": gauge},
		],
	}


func test_weapon_bots_swing_from_farther_than_boxers() -> void:
	var c := GameConfig.new()
	var gap := BotController.attack_range(1, c) * 1.2
	var knight := BotController.new(1, c).sample(_view(CharacterData.KNIGHT, Vector3(gap, 0, 0), Vector3.ZERO))
	var rogue := BotController.new(1, c).sample(_view(CharacterData.ROGUE, Vector3(gap, 0, 0), Vector3.ZERO))
	assert_true(knight.light, "the long weapon reaches")
	assert_false(rogue.light, "the boxer closes in first")
	assert_lt(rogue.move_x, 0.0)


func test_melee_bots_turn_to_the_foe_before_swinging() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var away := bot.sample(_view(CharacterData.ROGUE, Vector3(1, 0, 0), Vector3.ZERO, Vector3(1, 0, 0)))
	assert_false(away.light, "an attack starts along the facing, so no swing while facing away")
	assert_lt(away.move_x, 0.0, "steps toward the foe to turn")
	var facing := bot.sample(_view(CharacterData.ROGUE, Vector3(1, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0)))
	assert_true(facing.light)


func test_character_bots_skip_the_mirror_stagger() -> void:
	var c := GameConfig.new()
	var slot1 := {"style": StyleCatalog.BOXER, "special": SpecialCatalog.DASH_RUSH}
	var classic := {"style": StyleCatalog.CLASSIC, "special": ""}
	assert_eq(BotStyleSense.melee_range(slot1, 1, c), c.bot_attack_range * c.boxer_reach_mul)
	assert_eq(BotStyleSense.melee_range(classic, 1, c), BotController.attack_range(1, c))


func test_ranged_bot_backs_off_when_the_foe_is_close() -> void:
	var c := GameConfig.new()
	var f := BotController.new(1, c).sample(_view(CharacterData.MAGE, Vector3(1.5, 0, 0), Vector3.ZERO))
	assert_gt(f.move_x, 0.0, "steps away from the foe")
	assert_false(f.light)


func test_ranged_bot_turns_then_shoots_in_its_band() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var away := bot.sample(_view(CharacterData.MAGE, Vector3(5, 0, 0), Vector3.ZERO, Vector3(1, 0, 0)))
	assert_lt(away.move_x, 0.0, "turns toward the foe first")
	assert_false(away.light)
	var aimed := bot.sample(_view(CharacterData.MAGE, Vector3(5, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0)))
	assert_true(aimed.light, "fires once facing the foe")


func test_ranged_bot_closes_in_from_afar() -> void:
	var c := GameConfig.new()
	var f := BotController.new(1, c).sample(_view(CharacterData.MAGE, Vector3(9, 0, 0), Vector3(-0.5, 0, 0)))
	assert_lt(f.move_x, 0.0)


func test_full_gauge_fires_the_special_in_reach() -> void:
	var c := GameConfig.new()
	var near := BotController.new(1, c).sample(
			_view(CharacterData.BARBARIAN, Vector3(2, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0), SpecialGauge.MAX))
	assert_true(near.heavy and near.guard, "heavy + guard on the same tick")
	var far := BotController.new(1, c).sample(
			_view(CharacterData.BARBARIAN, Vector3(7, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0), SpecialGauge.MAX))
	assert_false(far.heavy and far.guard, "the slam cannot reach that far")
	var empty := BotController.new(1, c).sample(
			_view(CharacterData.BARBARIAN, Vector3(2, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0), 50.0))
	assert_false(empty.heavy and empty.guard, "no special without a full gauge")


func test_the_fireball_is_fired_from_range() -> void:
	var c := GameConfig.new()
	var f := BotController.new(1, c).sample(
			_view(CharacterData.MAGE, Vector3(7, 0, 0), Vector3.ZERO, Vector3(-1, 0, 0), SpecialGauge.MAX))
	assert_true(f.heavy and f.guard)
	assert_lt(f.move_x, 0.0, "aimed at the foe")


func test_character_bots_use_projectiles_and_specials_in_a_match() -> void:
	var c := GameConfig.new()
	var chars: Array[String] = [CharacterData.MAGE, CharacterData.KNIGHT]
	var w := World.new(c, 3, 2, null, chars)
	var bots: Array[BotController] = [BotController.new(0, c), BotController.new(1, c)]
	var seen := {}
	while not w.match_over and w.tick_count < 60 * 60 * 5:
		var view := w.state_view()
		w.tick([bots[0].sample(view), bots[1].sample(view)] as Array[InputFrame])
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
	for type: String in ["projectile_spawn", "projectile_hit", "gauge_full", "special_start", "special_hit"]:
		assert_true(seen.has(type), "%s happens in a bot match" % type)
	assert_true(w.match_over, "the match ends")
