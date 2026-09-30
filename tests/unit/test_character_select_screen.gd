extends GutTest
## Character select screen (Phase 5 T9, PRD-LOCAL-01, DS-CMP-08/10, DS-TOK-06): keys and pads per
## player, mouse for P1, cards showing whose cursor is on them with the player-color ring once
## locked, PlayerSlots with prompts per device, the setup filled with humans' and bots' characters
## and the character_selected / select_cancelled tracking.

var _tracked: Array = []


func _screen(setup: MatchSetup) -> CharacterSelectScreen:
	_tracked.clear()
	var s := CharacterSelectScreen.new()
	s.setup = setup
	s.track = func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog: %s" % [n, EventCatalog.validate(n, p)])
		_tracked.append([n, p])
	var t := [1000]
	s.clock_ms = func() -> int: return t[0]
	add_child_autofree(s)
	t[0] = 3500
	return s


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _pad(device: int, button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	return e


func _props(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


func test_one_player_picks_with_keys_and_bots_are_drawn() -> void:
	var setup := MatchSetup.vs_bots(3, 4)
	var s := _screen(setup)
	var chosen := [false]
	s.characters_chosen.connect(func() -> void: chosen[0] = true)
	await wait_process_frames(1)
	s._input(_key(KEY_RIGHT))
	s._input(_key(KEY_RIGHT))
	assert_eq(s.view().cards[2].state(), SelectCard.State.FOCUS)
	assert_eq(s.view().cards[2].marks(), [0] as Array[int], "P1's marker sits on the browsed card")
	assert_eq(s.view().slots[0].character_text(), CharacterCards.title_of(CharacterData.KNIGHT))
	assert_true(s.view().slots[1].bot_tag().visible)
	s._input(_key(KEY_Z))
	assert_true(chosen[0])
	assert_eq(s.view().cards[2].state(), SelectCard.State.SELECTED)
	assert_eq(s.view().cards[2].ring_color, PlayerStyle.color(0), "the ring is P1's color")
	assert_eq(setup.characters()[0], CharacterData.KNIGHT)
	var picked := _props("character_selected")
	assert_eq(picked.size(), 3)
	assert_eq(picked[0]["browse_count"], 2)
	assert_eq(picked[0]["input_device"], "keyboard")
	assert_eq([picked[1]["is_bot"], picked[1]["input_device"]], [true, MatchSetup.INPUT_BOT])
	assert_eq(picked[2]["style"], CharacterData.style_of(String(picked[2]["character"])))


func test_mouse_hover_browses_and_click_picks_for_p1() -> void:
	var setup := MatchSetup.vs_bots(2, 1)
	var s := _screen(setup)
	await wait_process_frames(1)
	s.view().cards[3].hovered.emit()
	assert_eq(s.model().focus(0), 3)
	s.view().cards[1].press()
	assert_eq(setup.characters()[0], CharacterData.ROGUE, "a click picks the clicked card")


func test_two_players_ready_up_separately_and_cancel_unlocks() -> void:
	var setup := MatchSetup.local_versus(2, 1)
	var s := _screen(setup)
	var chosen := [false]
	s.characters_chosen.connect(func() -> void: chosen[0] = true)
	await wait_process_frames(1)
	s._input(_key(KEY_D))
	s._input(_key(KEY_F))
	assert_eq(s.view().slots[1].state(), PlayerSlot.State.READY, "P2 locked with F")
	assert_eq(s.view().cards[2].ring_color, PlayerStyle.color(1))
	s._input(_key(KEY_G))
	assert_eq(s.view().slots[1].state(), PlayerSlot.State.CHOOSING, "G takes it back")
	s._input(_key(KEY_F))
	s._input(_key(KEY_LEFT))
	s._input(_key(KEY_Z))
	assert_true(chosen[0])
	assert_eq(setup.characters(), [CharacterData.MAGE, CharacterData.KNIGHT] as Array[String])
	assert_eq(_props("character_selected").size(), 2)


func test_each_pad_drives_its_own_player_and_changes_the_prompts() -> void:
	var s := _screen(MatchSetup.local_versus(2, 1))
	await wait_process_frames(1)
	var pads := s.devices().assigner()
	pads.connect_device(40)
	pads.connect_device(41)
	s._input(_pad(41, JOY_BUTTON_DPAD_RIGHT))
	assert_eq(s.model().focus(1), 2, "the second pad is P2's")
	assert_eq(s.model().focus(0), 0)
	s._input(_pad(41, JOY_BUTTON_A))
	assert_eq(s.model().state(1), CharacterSelectModel.READY)
	var p2_prompts := s.devices().prompts(1)
	assert_eq(p2_prompts[1]["caps"][0]["glyph"], SelectPrompts.GLYPH_A, "P2 sees pad prompts")
	s._input(_key(KEY_LEFT))
	assert_eq(s.devices().prompts(0)[0]["caps"][0].get("arrow"), Vector2.LEFT, "P1 used the keys: key prompts")


func test_cancel_while_choosing_goes_back_and_reshow_reopens() -> void:
	var s := _screen(MatchSetup.vs_bots(2, 1))
	var backs := [0]
	s.cancelled.connect(func() -> void: backs[0] += 1)
	await wait_process_frames(1)
	s._input(_key(KEY_ESCAPE))
	assert_eq(backs[0], 1)
	assert_eq(_props("select_cancelled")[0], {"screen": "character", "dwell_ms": 2500})
	s._input(_key(KEY_ESCAPE))
	assert_eq(backs[0], 1, "only once")
	s.visible = false
	s.visible = true
	s._input(_key(KEY_X))
	assert_eq(backs[0], 2, "a fresh visit can leave again")


func test_the_same_line_up_is_tracked_once_across_visits() -> void:
	var s := _screen(MatchSetup.vs_bots(2, 1))
	await wait_process_frames(1)
	s.confirm(0, "keyboard")
	assert_eq(_props("character_selected").size(), 2)
	s.visible = false
	s.visible = true
	s.confirm(0, "keyboard")
	assert_eq(_props("character_selected").size(), 2, "back from the arena, same pick: nothing new")
	s.visible = false
	s.visible = true
	s._input(_key(KEY_RIGHT))
	s._input(_key(KEY_Z))
	assert_eq(_props("character_selected").size(), 4, "a different pick is a new line-up")


func test_p2_cancel_while_choosing_does_not_leave() -> void:
	var s := _screen(MatchSetup.local_versus(2, 1))
	var backs := [0]
	s.cancelled.connect(func() -> void: backs[0] += 1)
	await wait_process_frames(1)
	s._input(_key(KEY_G))
	assert_eq(backs[0], 0, "a stray P2 key never throws away P1's pick")
	s.back_button().pressed.emit()
	assert_eq(backs[0], 1, "뒤로 still leaves")


func test_compact_layout_can_switch_after_a_resize() -> void:
	var s := _screen(MatchSetup.vs_bots(2, 1))
	await wait_process_frames(1)
	s.view().set_compact(true)
	assert_eq(s.view().portraits[0].custom_minimum_size.y, CharacterSelectLayout.COMPACT_THUMB_HEIGHT)
	assert_true(s.view().portraits[0].close_up)
	assert_false(s.view().cards[0].get("_caption").text.contains("\n"), "one-line caption")
	s.view().set_compact(false)
	assert_eq(s.view().portraits[0].custom_minimum_size.y, float(DS.CARD_THUMB_HEIGHT))
