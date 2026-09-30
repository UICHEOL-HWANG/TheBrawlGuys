class_name DeviceId
extends RefCounted
## Anonymous per-install id (platform A2): a UUID kept in user://device.cfg ([device] id).
## Amplitude joins anonymous events to the user after login through it.

const DEFAULT_PATH := "user://device.cfg"
const SECTION := "device"
const KEY := "id"
const UUID_LENGTH := 36


static func load_or_create(path: String = DEFAULT_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var existing := String(cfg.get_value(SECTION, KEY, ""))
		if existing.length() == UUID_LENGTH:
			return existing
	var id := Uuid.v4()
	cfg.set_value(SECTION, KEY, id)
	var err := cfg.save(path)
	if err != OK:
		push_warning("DeviceId: cannot save %s (%s); the id lasts this run only" % [path, error_string(err)])
	return id
