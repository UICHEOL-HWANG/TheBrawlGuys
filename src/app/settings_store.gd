class_name SettingsStore
extends RefCounted
## Player settings on disk: user://settings.cfg, one ConfigFile section per area ([hud]
## key_hints = bool, later audio, controls, accessibility). Every set saves at once; a missing
## or unreadable file reads as defaults, and an unreadable file is never overwritten (that would
## wipe every other section).

const DEFAULT_PATH := "user://settings.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func get_value(section: String, key: String, default: Variant) -> Variant:
	var cfg := _read()
	return default if cfg == null else cfg.get_value(section, key, default)


func get_bool(section: String, key: String, default: bool) -> bool:
	var v: Variant = get_value(section, key, default)
	return bool(v) if typeof(v) == TYPE_BOOL else default


func set_value(section: String, key: String, value: Variant) -> void:
	var cfg := _read()
	if cfg == null:
		return
	cfg.set_value(section, key, value)
	var err := cfg.save(_path)
	if err != OK:
		push_warning("SettingsStore: cannot write %s (%s)" % [_path, error_string(err)])


## Null when the file exists but cannot be read.
func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_path):
		var err := cfg.load(_path)
		if err != OK:
			push_warning("SettingsStore: cannot read %s (%s), left untouched" % [_path, error_string(err)])
			return null
	return cfg
