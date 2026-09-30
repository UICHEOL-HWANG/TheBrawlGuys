extends GutTest
## SelectCard (design.md DS-CMP-08) and the arena select screen (Phase 4 T7, PRD-UI-02): card
## states, keyboard / mouse selection, tracking and the router's pop_to.

const CARD := preload("res://src/ui/components/select_card/select_card.tscn")

var _tracked: Array = []


func _card() -> SelectCard:
	var c := CARD.instantiate() as SelectCard
	add_child_autofree(c)
	return c


func _screen() -> ArenaSelectScreen:
	_tracked.clear()
	var s := ArenaSelectScreen.new()
	s.track = func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog" % n)
		_tracked.append([n, p])
	var t := [1000]
	s.clock_ms = func() -> int: return t[0]
	add_child_autofree(s)
	t[0] = 4200
	return s


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func test_card_states_use_ds_tokens() -> void:
	var c := _card()
	assert_eq(c.state(), SelectCard.State.IDLE)
	assert_eq(c.custom_minimum_size.x, float(DS.CARD_WIDTH))
	c.set_state(SelectCard.State.FOCUS)
	var box := c.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.border_color, DS.PETAL_YELLOW, "focus ring")
	assert_eq(c.scale, Vector2.ONE * DS.CARD_FOCUS_SCALE)
	c.set_state(SelectCard.State.SELECTED)
	assert_eq((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color, DS.UI_ACCENT, "selected ring")
	c.ring_color = DS.P2
	c.set_state(SelectCard.State.SELECTED)
	assert_eq((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color, DS.P2, "player color ring (Phase 5)")
	c.set_state(SelectCard.State.LOCKED)
	assert_eq((c.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, DS.UI_SURFACE_DIM)


func test_locked_cards_cannot_be_pressed_and_focus_never_overrides_them() -> void:
	var c := _card()
	watch_signals(c)
	c.set_state(SelectCard.State.LOCKED)
	c.press()
	assert_signal_not_emitted(c, "pressed")
	c.focus_entered.emit()
	assert_eq(c.state(), SelectCard.State.LOCKED)
	c.set_state(SelectCard.State.IDLE)
	c.press()
	assert_signal_emitted(c, "pressed")


func test_card_shows_title_icons_and_diorama() -> void:
	var c := _card()
	c.set_preview()
	assert_eq(c.title_text(), "호숫가 캠프장")
	assert_eq(c.icon_kinds(), ["water", "fire"] as Array[String])
	assert_false(c.thumb().diorama().is_empty())


func test_gallery_registers_the_select_card() -> void:
	var found := false
	for entry: Array in load("res://src/debug/ds_gallery.gd").get("COMPONENTS"):
		if String(entry[1]).ends_with("select_card.tscn"):
			found = true
	assert_true(found)


func test_every_stage_gets_a_card_with_its_gimmicks() -> void:
	var entries := ArenaCards.entries(GameConfig.new())
	var ids: Array[String] = []
	for e: Dictionary in entries:
		ids.append(String(e["id"]))
	assert_eq(ids, ArenaCatalog.stage_ids())
	var icons := {}
	for e: Dictionary in entries:
		icons[e["id"]] = e["icons"]
	assert_eq(icons["lakeside_camp"], ["water", "fire"] as Array[String])
	assert_eq(icons["log_bridge"], ["water", "crack"] as Array[String])
	assert_eq(icons["mushroom_forest"], ["bounce"] as Array[String])
	assert_eq(icons["foggy_forest"], ["fog"] as Array[String])


func test_keyboard_browses_and_confirms() -> void:
	var s := _screen()
	await wait_process_frames(2)
	watch_signals(s)
	assert_eq(s.focus_index(), 0)
	s._input(_key(KEY_LEFT))
	assert_eq(s.focus_index(), s.cards().size() - 1, "wraps around")
	s._input(_key(KEY_RIGHT))
	s._input(_key(KEY_RIGHT))
	assert_eq(s.focus_index(), 1)
	assert_eq(s.cards()[1].state(), SelectCard.State.FOCUS)
	s._input(_key(KEY_Z))
	assert_signal_emitted_with_parameters(s, "arena_chosen", [s.card_ids()[1]])
	assert_eq(s.cards()[1].state(), SelectCard.State.SELECTED)
	assert_eq(_tracked.size(), 1)
	assert_eq(_tracked[0][0], "arena_selected")
	assert_eq(_tracked[0][1], {"arena": s.card_ids()[1], "browse_count": 3})
	s._input(_key(KEY_ENTER))
	assert_eq(_tracked.size(), 1, "one choice only")


func test_escape_goes_back_and_tracks_the_cancel() -> void:
	var s := _screen()
	await wait_process_frames(1)
	watch_signals(s)
	s._input(_key(KEY_X))
	assert_signal_emitted(s, "cancelled")
	assert_eq(_tracked[0], ["select_cancelled", {"screen": "arena", "dwell_ms": 3200}])


func test_click_or_tap_picks_a_card() -> void:
	var s := _screen()
	await wait_process_frames(1)
	watch_signals(s)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = s.cards()[3].size * 0.5
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	s.cards()[3].mouse_entered.emit()
	s.cards()[3]._gui_input(down)
	s.cards()[3]._gui_input(up)
	assert_signal_emitted_with_parameters(s, "arena_chosen", [s.card_ids()[3]])
	assert_eq(_tracked[0][1]["browse_count"], 1, "hovering counts as browsing")


func test_back_button_cancels() -> void:
	var s := _screen()
	await wait_process_frames(1)
	watch_signals(s)
	s.back_button().pressed.emit()
	assert_signal_emitted(s, "cancelled")


func test_router_pops_back_to_an_earlier_screen() -> void:
	var r := ScreenRouter.new()
	r.animate = false
	var seen: Array = []
	r.track = func(n: String, p: Dictionary) -> void: seen.append([n, p])
	add_child_autofree(r)
	for id: String in ["title", "arena", "match"]:
		var c := Control.new()
		r.push(id, c)
	r.pop_to("title")
	assert_eq(r.current_id(), "title")
	assert_eq(r.depth(), 1)
	assert_true((r.current() as Control).visible, "the title shows again")
	assert_eq(seen.back()[1]["from_screen"], "match")
