class_name Secrets
extends RefCounted
## Public client keys (platform A1) from config/secrets.local.cfg (gitignored, exported with the
## game). Missing values disable tracking/login with a warning; a Supabase service key is refused.

const DEFAULT_PATH := "res://config/secrets.local.cfg"
const DEFAULT_LOOPBACK_PORT := 54321
## The loopback port must be a fixed, unprivileged port (it is listed in Supabase redirect URLs).
const MIN_PORT := 1024
const MAX_PORT := 65535
## Supabase secret-key prefix (new key format); never valid in a client.
const SECRET_KEY_PREFIX := "sb_secret_"
const SERVICE_ROLE := "service" + "_role"
## Online (Phase 6): public STUN always; TURN servers only when [net] turn_urls is set.
const DEFAULT_STUN := "stun:stun.l.google.com:19302"

var amplitude_api_key: String = ""
var supabase_url: String = ""
var supabase_anon_key: String = ""
var redirect_web: String = ""
var loopback_port: int = DEFAULT_LOOPBACK_PORT
var turn_urls: PackedStringArray = PackedStringArray()
var turn_username: String = ""
var turn_credential: String = ""


static func load_from(path: String = DEFAULT_PATH) -> Secrets:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		push_warning("Secrets: %s not loaded (%s) — analytics and login are disabled. Run scripts/set_secrets.sh."
				% [path, error_string(err)])
		return Secrets.new()
	var s := from_config(cfg)
	if not s.is_configured():
		push_warning("Secrets: missing %s in %s" % [", ".join(s.missing()), path])
	return s


static func from_config(cfg: ConfigFile) -> Secrets:
	var s := Secrets.new()
	s.amplitude_api_key = _text(cfg, "amplitude", "api_key")
	s.supabase_url = _text(cfg, "supabase", "url").trim_suffix("/")
	s.supabase_anon_key = _text(cfg, "supabase", "anon_key")
	s.redirect_web = _text(cfg, "auth", "redirect_web")
	s.loopback_port = int(cfg.get_value("auth", "loopback_port", DEFAULT_LOOPBACK_PORT))
	if s.loopback_port < MIN_PORT or s.loopback_port > MAX_PORT:
		push_warning("Secrets: auth.loopback_port %d outside %d-%d, using %d"
				% [s.loopback_port, MIN_PORT, MAX_PORT, DEFAULT_LOOPBACK_PORT])
		s.loopback_port = DEFAULT_LOOPBACK_PORT
	for url: String in _text(cfg, "net", "turn_urls").split(",", false):
		s.turn_urls.append(url.strip_edges())
	s.turn_username = _text(cfg, "net", "turn_username")
	s.turn_credential = _text(cfg, "net", "turn_credential")
	if is_service_key(s.supabase_anon_key):
		push_error("Secrets: supabase.anon_key is a service-role/secret key — refused. Use the anon/publishable key.")
		s.supabase_anon_key = ""
	return s


## True for keys that bypass row-level security: sb_secret_* or a JWT whose role is the service role.
static func is_service_key(key: String) -> bool:
	if key.begins_with(SECRET_KEY_PREFIX):
		return true
	var parts := key.split(".")
	if parts.size() != 3:
		return false
	return _b64url_decode(parts[1]).contains(SERVICE_ROLE)


func has_analytics() -> bool:
	return not amplitude_api_key.is_empty()


func has_supabase() -> bool:
	return not supabase_url.is_empty() and not supabase_anon_key.is_empty()


func is_configured() -> bool:
	return missing().is_empty()


func missing() -> PackedStringArray:
	var out := PackedStringArray()
	if amplitude_api_key.is_empty():
		out.append("amplitude.api_key")
	if supabase_url.is_empty():
		out.append("supabase.url")
	if supabase_anon_key.is_empty():
		out.append("supabase.anon_key")
	return out


static func _text(cfg: ConfigFile, section: String, key: String) -> String:
	return String(cfg.get_value(section, key, "")).strip_edges()


static func _b64url_decode(part: String) -> String:
	var b64 := part.replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	return Marshalls.base64_to_utf8(b64)
