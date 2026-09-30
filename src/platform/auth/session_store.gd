class_name SessionStore
extends RefCounted
## Signed-in session on disk (platform A4): user://session.cfg keeps [session] access_token,
## refresh_token, expires_at (unix s), user_id, plus [pkce] verifier while a web redirect is out.

const DEFAULT_PATH := "user://session.cfg"
const SESSION := "session"
const PKCE := "pkce"
const VERIFIER := "verifier"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func save(session: SupabaseSession) -> void:
	var cfg := _read()
	var data := session.to_dict()
	for key: String in data:
		cfg.set_value(SESSION, key, data[key])
	_write(cfg)


func load_session() -> SupabaseSession:
	var cfg := _read()
	if not cfg.has_section(SESSION):
		return null
	var data := {}
	for key: String in cfg.get_section_keys(SESSION):
		data[key] = cfg.get_value(SESSION, key)
	var session := SupabaseSession.from_dict(data)
	if session == null:
		push_warning("SessionStore: %s holds an incomplete session, ignored" % _path)
	return session


## Forgets the session (sign-out, rejected refresh).
func clear() -> void:
	var cfg := _read()
	if cfg.has_section(SESSION):
		cfg.erase_section(SESSION)
	_write(cfg)


func save_verifier(verifier: String) -> void:
	var cfg := _read()
	cfg.set_value(PKCE, VERIFIER, verifier)
	_write(cfg)


func peek_verifier() -> String:
	return String(_read().get_value(PKCE, VERIFIER, ""))


## Returns the stored verifier once and erases it (a code can be exchanged only once).
func take_verifier() -> String:
	var cfg := _read()
	var verifier := String(cfg.get_value(PKCE, VERIFIER, ""))
	if cfg.has_section(PKCE):
		cfg.erase_section(PKCE)
		_write(cfg)
	return verifier


func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_path):
		var err := cfg.load(_path)
		if err != OK:
			push_warning("SessionStore: cannot read %s (%s)" % [_path, error_string(err)])
	return cfg


func _write(cfg: ConfigFile) -> void:
	var err := cfg.save(_path)
	if err != OK:
		push_warning("SessionStore: cannot write %s (%s)" % [_path, error_string(err)])
