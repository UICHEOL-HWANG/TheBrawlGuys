class_name InstallInfo
extends RefCounted
## Install-level Amplitude user properties (platform A8, analytics-strategy §3.1): first_seen_at and
## install_build are written on the first run and never change; input_device_primary is the device
## with the most matches on this install. Kept in a ConfigFile: [install] and [devices] sections.

const DEFAULT_PATH := "user://install.cfg"
const INSTALL := "install"
const DEVICES := "devices"

var _path: String
var _cfg := ConfigFile.new()


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	if FileAccess.file_exists(_path) and _cfg.load(_path) != OK:
		push_warning("InstallInfo: cannot read %s; starting fresh" % _path)


## User properties; the first call on an install stores now_iso and build as the originals.
func properties(now_iso: String, build: String) -> Dictionary:
	if not _cfg.has_section_key(INSTALL, "first_seen_at"):
		_cfg.set_value(INSTALL, "first_seen_at", now_iso)
		_cfg.set_value(INSTALL, "install_build", build)
		_save()
	var out := {
		"first_seen_at": String(_cfg.get_value(INSTALL, "first_seen_at")),
		"install_build": String(_cfg.get_value(INSTALL, "install_build")),
	}
	var primary := _primary()
	if not primary.is_empty():
		out["input_device_primary"] = primary
	return out


## Campaign user properties: this visit's utm_* as given, plus initial_utm_* from the first visit
## that carried any (stored once, never overwritten).
func attribution(utm: Dictionary) -> Dictionary:
	if not utm.is_empty() and not _cfg.has_section_key(INSTALL, "initial_utm_set"):
		for key: String in utm:
			_cfg.set_value(INSTALL, "initial_" + key, String(utm[key]))
		_cfg.set_value(INSTALL, "initial_utm_set", true)
		_save()
	var out := utm.duplicate()
	for key: String in UtmParams.KEYS:
		if _cfg.has_section_key(INSTALL, "initial_" + key):
			out["initial_" + key] = String(_cfg.get_value(INSTALL, "initial_" + key))
	return out


## Counts one match on a device; returns the primary device afterwards.
func note_device(device: String) -> String:
	_cfg.set_value(DEVICES, device, int(_cfg.get_value(DEVICES, device, 0)) + 1)
	_save()
	return _primary()


func _primary() -> String:
	if not _cfg.has_section(DEVICES):
		return ""
	var best := ""
	var best_count := -1
	for device: String in _cfg.get_section_keys(DEVICES):
		var n := int(_cfg.get_value(DEVICES, device, 0))
		if n > best_count:
			best = device
			best_count = n
	return best


func _save() -> void:
	var err := _cfg.save(_path)
	if err != OK:
		push_warning("InstallInfo: cannot save %s (%s)" % [_path, error_string(err)])
