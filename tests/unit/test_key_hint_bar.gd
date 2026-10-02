extends GutTest
## KeyHintBar (design.md DS-CMP-16): keycaps light up from InputMap actions, the bar hides and
## shows from the chip or F2, the choice persists, and it stays away on touch devices.

const BAR := preload("res://src/ui/components/key_hint_bar/key_hint_bar.tscn")
const PATH := "user://test_key_hints.cfg"

var _tracked: Array[Dictionary] = []
var _touch: bool = false


func before_each() -> void:
	InputBindings.apply()
	_tracked.clear()
	_touch = false
	_remove()


func after_each() -> void:
	for action: String in InputBindings.P1:
		Input.action_release(action)
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _hud() -> KeyHintHud:
	var h := KeyHintHud.new()
	add_child_autofree(h)
	h.setup(DS.P1, func() -> bool: return _touch, SettingsStore.new(PATH),
			func(event_name: String, props: Dictionary) -> void: _tracked.append({"name": event_name, "props": props}))
	return h


func test_source_lists_the_p1_caps_with_bound_key_labels() -> void:
	var ids: Array[String] = []
	for cap: Dictionary in KeyHintSource.caps():
		ids.append(String(cap["id"]))
	assert_eq(ids, ["up", "left", "down", "right", "jump", "light", "heavy", "guard", "grab", "special"])
	var jump := KeyHintSource.cap("jump")
	assert_eq(jump["label"], "점프")
	assert_eq(jump["text"], "Space")
	assert_eq(KeyHintSource.cap("light")["text"], "Z")
	assert_eq(KeyHintSource.cap("left")["arrow"], Vector2.LEFT, "arrow keys are drawn as arrows")
	assert_eq(KeyHintSource.cap("special")["text"], "X+C", "the special is the heavy+guard chord")
	assert_eq(KeyHintSource.cap("special")["label"], "필살기")


func test_source_builds_the_caps_of_any_player() -> void:
	var special := KeyHintSource.cap("special", "p2")
	assert_eq(special["actions"], ["p2_heavy", "p2_guard"])
	assert_eq(special["text"], "G+H")
	assert_eq(KeyHintSource.cap("jump", "p2")["text"], "Q")
	assert_eq(KeyHintSource.cap("left", "p2")["arrow"], Vector2.ZERO, "letter keys stay letters")
	assert_eq(KeyHintSource.cap("left", "p2")["text"], "A")


func test_source_follows_rebinding() -> void:
	var old := InputMap.action_get_events("p1_light")
	InputMap.action_erase_events("p1_light")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	InputMap.action_add_event("p1_light", ev)
	assert_eq(KeyHintSource.cap("light")["text"], "K")
	InputMap.action_erase_events("p1_light")
	for e: InputEvent in old:
		InputMap.action_add_event("p1_light", e)


func test_combo_caps_are_pressed_only_when_every_action_is_held() -> void:
	var combo: Array[String] = ["p1_heavy", "p1_guard"]
	assert_eq(KeyHintSource.combo_text(combo), "X+C")
	Input.action_press("p1_heavy")
	assert_false(KeyHintSource.is_held(combo))
	Input.action_press("p1_guard")
	assert_true(KeyHintSource.is_held(combo))


func test_keycap_press_and_release() -> void:
	var cap := KeyCap.new()
	add_child_autofree(cap)
	cap.accent = DS.P1
	cap.set_state(KeyCap.State.PRESSED)
	assert_eq(cap.state(), KeyCap.State.PRESSED)
	assert_eq(cap.scale, DS.PRESS_SQUISH, "press squish")
	cap.set_state(KeyCap.State.IDLE)
	assert_eq(cap.state(), KeyCap.State.IDLE)
	await wait_seconds(DS.MOTION_SQUISH + 0.05)
	assert_almost_eq(cap.fill(), 0.0, 0.01, "the color fades back")
	assert_eq(cap.scale, Vector2.ONE)


func test_pressing_an_action_lights_its_cap() -> void:
	var h := _hud()
	await wait_process_frames(2)
	assert_eq(h.bar().cap_state("jump"), KeyCap.State.IDLE)
	Input.action_press("p1_jump")
	await wait_process_frames(2)
	assert_eq(h.bar().cap_state("jump"), KeyCap.State.PRESSED)
	assert_eq(h.bar().cap_state("light"), KeyCap.State.IDLE)
	Input.action_release("p1_jump")
	await wait_process_frames(2)
	assert_eq(h.bar().cap_state("jump"), KeyCap.State.IDLE)


func test_toggle_hides_persists_and_tracks() -> void:
	var h := _hud()
	assert_eq(h.bar().state(), KeyHintBar.State.SHOWN, "shown by default")
	h.toggle()
	assert_eq(h.bar().state(), KeyHintBar.State.HIDDEN)
	assert_true(h.bar().chip().visible, "the chip stays to bring it back")
	assert_eq(h.bar().chip().text(), "키 보기")
	assert_false(SettingsStore.new(PATH).get_bool("hud", "key_hints", true), "saved")
	assert_eq(_tracked.size(), 1)
	assert_eq(_tracked[0]["name"], "settings_changed")
	assert_eq(_tracked[0]["props"], {"key": "hud.key_hints", "old": "true", "new": "false"})
	assert_true(EventCatalog.validate("settings_changed", _tracked[0]["props"]).is_empty())


func test_hiding_keeps_the_chip_where_it_was() -> void:
	var h := _hud()
	await wait_process_frames(3)
	var chip_at := h.bar().chip().get_global_rect()
	var bar_at := h.bar().get_global_rect()
	h.toggle()
	await wait_seconds(DS.MOTION_BASE + 0.1)  # the keys fade out
	await wait_process_frames(2)
	assert_false(h.bar().keys_visible(), "the keys are gone")
	assert_eq(h.bar().chip().get_global_rect(), chip_at, "the toggle stays under the cursor")
	assert_eq(h.bar().get_global_rect(), bar_at, "the bar keeps its place, so nothing below moves")
	h.toggle()
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_true(h.bar().keys_visible())
	assert_eq(h.bar().chip().get_global_rect(), chip_at)


func test_hidden_choice_is_restored_by_a_new_hud() -> void:
	SettingsStore.new(PATH).set_value("hud", "key_hints", false)
	var h := _hud()
	assert_eq(h.bar().state(), KeyHintBar.State.HIDDEN)
	h.toggle()
	assert_eq(h.bar().state(), KeyHintBar.State.SHOWN)
	assert_eq(h.bar().chip().text(), "키 숨기기")
	assert_true(SettingsStore.new(PATH).get_bool("hud", "key_hints", false))


func test_f2_and_the_chip_toggle() -> void:
	var h := _hud()
	var f2 := InputEventAction.new()
	f2.action = KeyHintHud.TOGGLE_ACTION
	f2.pressed = true
	Input.parse_input_event(f2)
	await wait_process_frames(2)
	assert_eq(h.bar().state(), KeyHintBar.State.HIDDEN, "F2 hides")
	h.bar().chip().pressed.emit()
	assert_eq(h.bar().state(), KeyHintBar.State.SHOWN, "the chip shows it again")


func test_f2_is_bound_and_not_h() -> void:
	assert_true(InputMap.has_action(KeyHintHud.TOGGLE_ACTION))
	var keys: Array[int] = []
	for ev: InputEvent in InputMap.action_get_events(KeyHintHud.TOGGLE_ACTION):
		keys.append((ev as InputEventKey).physical_keycode)
	assert_eq(keys, [KEY_F2])


func test_hidden_when_the_device_is_touch() -> void:
	var h := _hud()
	await wait_process_frames(2)
	assert_true(h.visible)
	_touch = true
	await wait_process_frames(2)
	assert_false(h.visible, "touch controls replace the key bar")
	Input.action_press("p1_jump")
	await wait_process_frames(2)
	assert_eq(h.bar().cap_state("jump"), KeyCap.State.IDLE, "no polling while hidden")


func test_bar_sits_at_the_bottom_inside_the_viewport() -> void:
	var h := _hud()
	await wait_process_frames(3)
	var vp := get_viewport().get_visible_rect()
	var rect := h.bar().get_global_rect()
	assert_gt(rect.position.y, vp.size.y * 0.5, "controls live at the bottom")
	assert_lte(rect.end.y, vp.end.y - DS.S5, "s5 margin inside the safe area")
	assert_gte(rect.position.x, vp.position.x)
	assert_lte(rect.end.x, vp.end.x)


func test_gallery_preview_animates_presses() -> void:
	var bar := BAR.instantiate() as KeyHintBar
	add_child_autofree(bar)
	bar.set_preview()
	var seen := false
	for i: int in 30:
		await wait_process_frames(2)
		for cap: Dictionary in KeyHintSource.caps():
			if bar.cap_state(String(cap["id"])) == KeyCap.State.PRESSED:
				seen = true
	assert_true(seen, "preview lights keys by itself")


func test_match_scene_shows_key_hints_for_the_local_player() -> void:
	var main: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)
	var hud: Hud = main.call("get_hud")
	assert_not_null(hud.key_hints(), "keyboard player gets the key bar")
	assert_eq(hud.key_hints().bar().accent(), DS.P1)


func _gauge_view(special: String, gauge: float) -> Dictionary:
	return {"fighters": [{"id": 0, "special": special, "gauge": gauge}]}


func test_special_cap_shows_when_the_gauge_is_full() -> void:
	var h := _hud()
	h.update_gauges(_gauge_view("slam", 40.0))
	assert_false(h.bar().cap_ready("special"))
	h.update_gauges(_gauge_view("slam", SpecialGauge.MAX))
	assert_true(h.bar().cap_ready("special"), "a full gauge rings the special cap")
	assert_false(h.bar().cap_ready("heavy"), "only the special cap")
	h.update_gauges(_gauge_view("", SpecialGauge.MAX))
	assert_false(h.bar().cap_ready("special"), "no special (classic fighter): never ready")
	h.update_gauges({"fighters": []})
	assert_false(h.bar().cap_ready("special"), "a view without the slot is ignored")


func test_keycap_ready_ring() -> void:
	var cap := KeyCap.new()
	add_child_autofree(cap)
	assert_false(cap.is_ready())
	cap.set_ready(true)
	assert_true(cap.is_ready())
	cap.set_state(KeyCap.State.PRESSED)
	assert_true(cap.is_ready(), "pressing keeps the ready ring")


func test_two_bars_go_compact_only_when_they_do_not_fit() -> void:
	var h := KeyHintHud.new()
	add_child_autofree(h)
	var players: Array[Dictionary] = [
		{"prefix": "p1", "slot": 0, "accent": DS.P1}, {"prefix": "p2", "slot": 1, "accent": DS.P2}]
	h.setup_players(players, func() -> bool: return false, SettingsStore.new(PATH),
			func(_n: String, _p: Dictionary) -> void: pass)
	h.fit_to(4000.0)
	var full := h.needed_width()
	assert_false(h.bars()[0].is_compact(), "room enough: full size")
	h.fit_to(full - 1.0)
	assert_true(h.bars()[0].is_compact() and h.bars()[1].is_compact())
	assert_lt(h.needed_width(), full - 100.0, "compact saves room (phone scale 1.6 needs ~90 px)")
	assert_false(h.bars()[1].chip().visible and h.bars()[0].chip().visible, "one chip for both bars")


func test_a_single_bar_never_goes_compact() -> void:
	var h := _hud()
	h.fit_to(100.0)
	assert_false(h.bar().is_compact())


func test_bars_hidden_at_start_fit_again_when_shown() -> void:
	SettingsStore.new(PATH).set_value("hud", "key_hints", false)
	var h := KeyHintHud.new()
	add_child_autofree(h)
	var players: Array[Dictionary] = [
		{"prefix": "p1", "slot": 0, "accent": DS.P1}, {"prefix": "p2", "slot": 1, "accent": DS.P2}]
	h.setup_players(players, func() -> bool: return false, SettingsStore.new(PATH),
			func(_n: String, _p: Dictionary) -> void: pass)
	assert_false(h.is_shown())
	var vp_width := get_viewport().get_visible_rect().size.x
	h.toggle()
	assert_true(h.is_shown())
	assert_lte(h.needed_width(), vp_width - DS.S5 * 2, "shown bars fit the screen (compact if needed)")


func test_two_bars_too_wide_even_compact_shrink_to_fit() -> void:
	var h := KeyHintHud.new()
	add_child_autofree(h)
	var players: Array[Dictionary] = [
		{"prefix": "p1", "slot": 0, "accent": DS.P1}, {"prefix": "p2", "slot": 1, "accent": DS.P2}]
	h.setup_players(players, func() -> bool: return false, SettingsStore.new(PATH),
			func(_n: String, _p: Dictionary) -> void: pass)
	await wait_process_frames(2)
	h.fit_to(2000.0)
	assert_eq(h.fit_scale(), 1.0, "room to spare: full size")
	h.fit_to(900.0)
	assert_false(h.bar().is_compact(), "shrunk at full gaps, not compact and shrunk")
	assert_lt(h.fit_scale(), 1.0, "compact is not enough: the row shrinks")
	assert_lte(h.needed_width() * h.fit_scale(), 900.0 + 0.5, "never clipped")
	h.fit_to(2000.0)
	assert_eq(h.fit_scale(), 1.0, "back to full size when the screen grows")
