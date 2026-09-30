class_name SupabaseHub
extends RefCounted
## The game's single SupabaseClient (platform A3/A4). Supabase rotates refresh tokens, so sign-in
## and match uploads must share one client (and its single-flight refresh) and one session file.
## null when offline: headless/test runs or missing keys.

static var _client: SupabaseClient = null
static var _resolved: bool = false


static func client() -> SupabaseClient:
	if _resolved:
		return _client
	_resolved = true
	if not PlatformEnv.is_live():
		return null
	var secrets := Secrets.load_from()
	if not secrets.has_supabase():
		return null
	var root := (Engine.get_main_loop() as SceneTree).root
	_client = SupabaseClient.new(secrets.supabase_url, secrets.supabase_anon_key, GodotHttpTransport.new(root))
	var store := SessionStore.new()
	_client.session = store.load_session()
	_client.session_changed.connect(func(s: SupabaseSession) -> void:
		if s != null:
			store.save(s)
		else:
			store.clear())
	return _client
