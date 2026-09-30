extends GutTest
## PlayerSlot (design.md DS-CMP-10): a participant in the player's color, number and shape, in one
## of empty · choosing · ready · disconnected, with the character it plays and the button prompts
## of the device that player uses (DS-TOK-06).

const SLOT := preload("res://src/ui/components/player_slot/player_slot.tscn")


func _slot(index: int) -> PlayerSlot:
	var s := SLOT.instantiate() as PlayerSlot
	add_child_autofree(s)
	s.setup(index)
	return s


func test_identity_is_number_color_and_shape() -> void:
	var s := _slot(2)
	assert_eq(s.number_text(), "P3")
	assert_eq(s.marker().get("_index"), 2, "P3's square marker in P3's color")


func test_states_change_the_status_and_the_ring() -> void:
	var s := _slot(1)
	assert_eq(s.state(), PlayerSlot.State.EMPTY)
	assert_eq(s.status_text(), PlayerSlot.STATUS[PlayerSlot.State.EMPTY])
	s.set_state(PlayerSlot.State.CHOOSING)
	assert_eq(s.status_text(), PlayerSlot.STATUS[PlayerSlot.State.CHOOSING])
	s.set_state(PlayerSlot.State.READY)
	var box := s.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.border_color, PlayerStyle.color(1), "ready: a ring in the player's color")
	assert_eq(box.border_width_top, DS.STROKE_FOCUS)
	s.set_state(PlayerSlot.State.DISCONNECTED)
	assert_eq(s.status_text(), PlayerSlot.STATUS[PlayerSlot.State.DISCONNECTED])
	assert_true(s.marker().is_dimmed(), "a dropped player's marker dims")


func test_character_bot_tag_and_prompts() -> void:
	var s := _slot(0)
	s.set_character("나이트")
	assert_eq(s.character_text(), "나이트")
	s.set_bot(true)
	assert_true(s.bot_tag().visible)
	s.set_prompts(SelectPrompts.for_player("p1", SelectPrompts.DEVICE_GAMEPAD))
	assert_eq(s.prompt_row().row_count(), 3)
	s.set_prompts([])
	assert_false(s.prompt_row().visible, "no prompts, no row")
