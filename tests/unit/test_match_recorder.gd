extends GutTest
## Match upload (platform A6): matches -> match_players -> match_events, only when signed in.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const URL := "https://proj.supabase.co"

var _http: FakeHttp
var _client: SupabaseClient
var _results: Array = []


func before_each() -> void:
	_http = FakeHttp.new()
	_results.clear()
	_client = SupabaseClient.new(URL, "anon", _http)
	_client.now_s = func() -> int: return 0
	_client.net_error_sink = func(_e: String, _s: int) -> void: pass


func _finished_match() -> MatchTelemetry:
	var t := MatchTelemetry.new(func(_n: String, _p: Dictionary) -> void: pass)
	t.begin({"match_id": "m-9", "mode": "bot", "arena": "default", "seed": 1, "local_slot": 0,
		"started_at": "2026-09-30T00:00:00Z", "slots": [
			{"slot": 0, "is_bot": false, "character": "Knight", "style": "default", "input_device": "keyboard"},
			{"slot": 1, "is_bot": true, "character": "Rogue", "style": "default", "input_device": "bot"}]})
	var f := func(id: int) -> Dictionary:
		return {"id": id, "spawn_id": 0, "pos": Vector3.ZERO, "state": 0, "on_ground": true, "damage": 0.0,
			"stocks": 1, "attack_kind": 0, "attack_ticks": 0}
	var view := {"tick": 30, "arena_radius": 10.0, "match_over": true, "winner": 1, "fighters": [f.call(0), f.call(1)]}
	var inputs: Array[InputFrame] = [InputFrame.make(1.0, 0.0), InputFrame.neutral()]
	t.on_frame([{"type": "grab", "attacker": 0, "target": 1, "pos": Vector3.ZERO}], [], view, inputs)
	t.end(view, false, 42)
	return t


func _done() -> Callable:
	return func(ok: bool) -> void: _results.append(ok)


func test_skips_without_a_client() -> void:
	assert_false(MatchRecorder.new(null).record(_finished_match(), _done()))
	assert_eq(_results, [false])


func test_skips_when_signed_out() -> void:
	assert_false(MatchRecorder.new(_client).record(_finished_match(), _done()))
	assert_eq(_http.requests.size(), 0)


func test_uploads_in_order_with_the_user_id() -> void:
	_client.session = SupabaseSession.new("a", "r", 999_999, "user-3")
	assert_true(MatchRecorder.new(_client).record(_finished_match(), _done()))
	assert_eq(_http.last()["url"], URL + "/rest/v1/matches")
	var m: Dictionary = (_http.last_json() as Array)[0]
	assert_eq(m["user_id"], "user-3")
	assert_eq(m["id"], "m-9")
	assert_eq(m["result"], "loss")
	_http.respond(201)
	assert_eq(_http.last()["url"], URL + "/rest/v1/match_players")
	assert_eq((_http.last_json() as Array).size(), 2)
	_http.respond(201)
	assert_eq(_http.last()["url"], URL + "/rest/v1/match_events")
	var rows: Array = _http.last_json()
	assert_eq(rows.size(), 3, "grab + two position samples")
	_http.respond(201)
	assert_eq(_http.last()["url"], URL + "/rest/v1/match_inputs")
	var inputs: Array = _http.last_json()
	assert_eq(inputs.size(), 2, "one input row per slot")
	assert_eq(inputs[0]["encoding"], InputBlob.ENCODING)
	assert_eq(int(inputs[0]["frame_count"]), 1)
	_http.respond(201)
	assert_eq(_results, [true])


func test_stops_at_the_first_failure() -> void:
	_client.session = SupabaseSession.new("a", "r", 999_999, "user-3")
	MatchRecorder.new(_client).record(_finished_match(), _done())
	_http.respond(500, "{}")
	assert_eq(_http.requests.size(), 1)
	assert_eq(_results, [false])


func test_unfinished_match_is_not_uploaded() -> void:
	_client.session = SupabaseSession.new("a", "r", 999_999, "user-3")
	var t := MatchTelemetry.new(func(_n: String, _p: Dictionary) -> void: pass)
	t.begin({"match_id": "m", "mode": "bot", "arena": "default", "seed": 1, "started_at": "x",
		"slots": [{"slot": 0, "is_bot": false, "character": "Knight", "style": "default", "input_device": "keyboard"}]})
	assert_false(MatchRecorder.new(_client).record(t, _done()))
	assert_eq(_http.requests.size(), 0)
