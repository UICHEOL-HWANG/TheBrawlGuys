extends GutTest
## SettingsStore: generic user settings in a ConfigFile (user://settings.cfg by default).

const PATH := "user://test_settings_store.cfg"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_missing_value_returns_the_default() -> void:
	var store := SettingsStore.new(PATH)
	assert_true(store.get_bool("hud", "key_hints", true))
	assert_false(store.get_bool("hud", "key_hints", false))


func test_value_survives_a_new_instance() -> void:
	SettingsStore.new(PATH).set_value("hud", "key_hints", false)
	assert_true(FileAccess.file_exists(PATH), "saved on set")
	assert_false(SettingsStore.new(PATH).get_bool("hud", "key_hints", true))


func test_other_sections_are_kept() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value("audio", "music", 0.5)
	store.set_value("hud", "key_hints", true)
	var again := SettingsStore.new(PATH)
	assert_eq(float(again.get_value("audio", "music", 1.0)), 0.5)
	assert_true(again.get_bool("hud", "key_hints", false))


func test_default_path_is_user_settings() -> void:
	assert_eq(SettingsStore.DEFAULT_PATH, "user://settings.cfg")


func test_an_unreadable_file_is_never_overwritten() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[audio\nmusic = = broken")
	f.close()
	var store := SettingsStore.new(PATH)
	assert_true(store.get_bool("hud", "key_hints", true), "defaults when unreadable")
	store.set_value("hud", "key_hints", false)
	assert_eq(FileAccess.get_file_as_string(PATH), "[audio\nmusic = = broken", "the file is left alone")
	assert_engine_error_count(2, "ConfigFile reports the parse error on each read")
