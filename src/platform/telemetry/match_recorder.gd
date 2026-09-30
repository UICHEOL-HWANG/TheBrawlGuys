class_name MatchRecorder
extends RefCounted
## Uploads a finished match's raw rows to Supabase (platform A6, PRD-DATA-04):
## matches -> match_players -> match_events (chunked by SupabaseClient). Only when signed in;
## otherwise nothing is sent. done(ok: bool) fires once.

var _client: SupabaseClient


## client may be null (offline build, missing keys): every record() is then skipped.
func _init(client: SupabaseClient) -> void:
	_client = client


## Live recorder for the game: stored session + keys, or an offline one in tests/headless runs.
static func create_default(host: Node) -> MatchRecorder:
	if not PlatformEnv.is_live():
		return MatchRecorder.new(null)
	var secrets := Secrets.load_from()
	if not secrets.has_supabase():
		return MatchRecorder.new(null)
	var client := SupabaseClient.new(secrets.supabase_url, secrets.supabase_anon_key, GodotHttpTransport.new(host))
	var store := SessionStore.new()
	client.session = store.load_session()
	client.session_changed.connect(func(s: SupabaseSession) -> void:
		if s != null:
			store.save(s)
		else:
			store.clear())
	return MatchRecorder.new(client)


## Returns false (and calls done(false)) when the match is skipped.
func record(telemetry: MatchTelemetry, done: Callable = Callable()) -> bool:
	if _client == null or not _client.has_session() or telemetry.match_row().is_empty():
		_finish(done, false)
		return false
	var match_row := telemetry.match_row().duplicate()
	match_row["user_id"] = _client.session.user_id
	var steps: Array = [["matches", [match_row]], ["match_players", telemetry.player_rows()],
		["match_events", telemetry.event_rows()]]
	_run(steps, 0, done)
	return true


func _run(steps: Array, index: int, done: Callable) -> void:
	if index >= steps.size():
		_finish(done, true)
		return
	var step: Array = steps[index]
	_client.rest_insert(String(step[0]), step[1], func(ok: bool, status: int, message: String) -> void:
		if not ok:
			push_warning("MatchRecorder: %s insert failed (%d) %s" % [step[0], status, message.left(200)])
			_finish(done, false)
			return
		_run(steps, index + 1, done))


static func _finish(done: Callable, ok: bool) -> void:
	if done.is_valid():
		done.call(ok)
