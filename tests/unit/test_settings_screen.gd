extends GutTest
## Settings (platform: 설정 화면): per-player sound volumes and reduce motion, kept in
## SettingsStore, applied to the buses at once, opened from the title.

const PATH := "user://test_settings_screen.cfg"

var _store: SettingsStore


func before_each() -> void:
	_store = SettingsStore.new(PATH)


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	AudioBuses.ensure(GameConfig.new())  # whatever a test did to the buses, the next one starts as designed


func _screen() -> SettingsScreen:
	var s := SettingsScreen.new()
	s.store = _store
	s.config = GameConfig.new()
	add_child_autofree(s)
	return s


func _bus_db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func test_volume_defaults_to_full_and_clamps() -> void:
	assert_eq(UserVolume.percent(_store, UserVolume.SFX), 100)
	UserVolume.set_percent(_store, UserVolume.SFX, 140)
	assert_eq(UserVolume.percent(_store, UserVolume.SFX), 100, "clamped to 100")
	UserVolume.set_percent(_store, UserVolume.MUSIC, -5)
	assert_eq(UserVolume.percent(_store, UserVolume.MUSIC), 0)


func test_percent_maps_to_decibels() -> void:
	assert_almost_eq(UserVolume.db(100), 0.0, 0.001)
	assert_almost_eq(UserVolume.db(50), -6.02, 0.01)
	assert_eq(UserVolume.db(0), UserVolume.MUTE_DB, "zero is silent")


func test_buses_follow_the_stored_volumes() -> void:
	var c := GameConfig.new()
	UserVolume.set_percent(_store, UserVolume.SFX, 50)
	UserVolume.set_percent(_store, UserVolume.MUSIC, 0)
	AudioBuses.ensure(c, _store)
	assert_almost_eq(_bus_db(AudioBuses.SFX), c.sfx_volume_db - 6.02, 0.01)
	assert_almost_eq(_bus_db(AudioBuses.UI), c.ui_volume_db - 6.02, 0.01, "UI clicks follow the sound slider")
	assert_eq(_bus_db(AudioBuses.MUSIC), UserVolume.MUTE_DB)
	AudioBuses.ensure(c)  # back to config values for the other tests
	assert_almost_eq(_bus_db(AudioBuses.SFX), c.sfx_volume_db, 0.001)


func test_sliders_show_saved_values_and_save_changes() -> void:
	UserVolume.set_percent(_store, UserVolume.MUSIC, 30)
	var s := _screen()
	assert_eq(s.slider(UserVolume.SFX).value, 100.0)
	assert_eq(s.slider(UserVolume.MUSIC).value, 30.0)
	s.slider(UserVolume.SFX).value = 40.0
	assert_eq(UserVolume.percent(_store, UserVolume.SFX), 40)
	assert_almost_eq(_bus_db(AudioBuses.SFX), s.config.sfx_volume_db + UserVolume.db(40), 0.01)
	assert_string_contains(s.value_text(UserVolume.SFX), "40")
	AudioBuses.ensure(s.config)


func test_reduce_motion_toggle_saves() -> void:
	var s := _screen()
	assert_false(s.motion_toggle().button_pressed)
	s.motion_toggle().button_pressed = true
	assert_true(SpecialCutInDirector.reduce_motion_setting(_store))
	assert_true(_store.get_bool("accessibility", "reduce_motion", false))


func test_bot_dda_toggle_shows_the_device_arm_and_saves_a_choice() -> void:
	var tracked: Array = []
	var s := SettingsScreen.new()
	s.store = _store
	s.config = GameConfig.new()
	s.track = func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, n)
		tracked.append([n, p])
	add_child_autofree(s)
	var arm_on := BotSquadFactory.variant(s.config, BotSquadFactory.AUTO, BotSquadFactory.HEADLESS_KEY) == BotSquad.ON
	assert_eq(s.dda_toggle().button_pressed, arm_on, "unset: the device's A/B arm")
	s.dda_toggle().button_pressed = not arm_on
	var want := BotSquad.OFF if arm_on else BotSquad.ON
	assert_eq(_store.get_value("bots", "dda", BotSquadFactory.AUTO), want, "BotSquadFactory reads it at match start")
	assert_eq(BotSquadFactory.variant(s.config, want, BotSquadFactory.HEADLESS_KEY), want)
	assert_eq(tracked.back()[1], {"key": DdaSetting.TRACK_KEY, "old": str(arm_on), "new": str(not arm_on)})
	assert_eq(DdaSetting.is_on(_store, s.config, BotSquadFactory.HEADLESS_KEY), not arm_on, "a reopened screen")


func test_bot_dda_toggle_is_off_and_locked_when_dda_is_disabled() -> void:
	var c := GameConfig.new()
	c.dda_enabled = 0
	_store.set_value("bots", "dda", BotSquad.ON)
	var s := SettingsScreen.new()
	s.store = _store
	s.config = c
	add_child_autofree(s)
	assert_false(s.dda_toggle().button_pressed)
	assert_true(s.dda_toggle().disabled)


func test_keys_cross_from_the_sliders_to_the_switches() -> void:
	var s := _screen()
	var music := s.slider(UserVolume.MUSIC)
	assert_eq(music.get_node(music.focus_neighbor_bottom), s.motion_toggle(), "↓ from the last slider")
	assert_eq(s.motion_toggle().get_node(s.motion_toggle().focus_neighbor_top), music, "↑ back")


func test_back_leaves_once_even_when_pressed_twice() -> void:
	var s := _screen()
	watch_signals(s)
	s.back()
	s.back()
	assert_signal_emit_count(s, "cancelled", 1)


func test_a_drag_saves_when_it_ends_not_on_every_step() -> void:
	var s := _screen()
	var sl := s.slider(UserVolume.SFX)
	sl.drag_started.emit()
	sl.value = 70.0
	sl.value = 45.0
	assert_eq(UserVolume.percent(_store, UserVolume.SFX), 100, "nothing written mid-drag")
	assert_almost_eq(_bus_db(AudioBuses.SFX), s.config.sfx_volume_db + UserVolume.db(45), 0.01, "but heard at once")
	sl.drag_ended.emit(true)
	assert_eq(UserVolume.percent(_store, UserVolume.SFX), 45)


func test_settings_flow_pushes_and_pops_the_screen() -> void:
	var router := ScreenRouter.new()
	router.animate = false
	router.track = func(_n: String, _p: Dictionary) -> void: pass
	add_child_autofree(router)
	router.push("title", Control.new())
	SettingsFlow.open(router, GameConfig.new())
	assert_eq(router.current_id(), SettingsFlow.SETTINGS)
	(router.current() as SettingsScreen).back()
	assert_eq(router.current_id(), "title")


func test_title_has_a_settings_button() -> void:
	var t := TitleScreen.new()
	add_child_autofree(t)
	watch_signals(t)
	assert_not_null(t.settings_button())
	t.settings_button().pressed.emit()
	assert_signal_emitted(t, "settings_requested")
