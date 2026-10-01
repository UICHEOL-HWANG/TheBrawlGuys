extends GutTest
## Room codes and the rooms table client (Phase 6, migration 0005): code alphabet / validation,
## create with collision retry, lookup, update and close over PostgREST.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const URL := "https://proj.supabase.co"
const MIGRATION := "res://supabase/migrations/0005_rooms.sql"

var _http: FakeHttp
var _api: RoomsApi
var _results: Array = []
var _codes: Array[String] = []


func before_each() -> void:
	_http = FakeHttp.new()
	var client := SupabaseClient.new(URL, "anon-key", _http)
	client.now_s = func() -> int: return 1_000
	client.session = SupabaseSession.new("access-1", "refresh-1", 100_000, "user-1")
	_api = RoomsApi.new(client)
	_codes = ["AAAAAA", "BBBBBB", "CCCCCC", "DDDDDD", "EEEEEE", "FFFFFF"]
	_api.new_code = func() -> String: return _codes.pop_front()
	_results.clear()


func test_codes_use_the_unambiguous_alphabet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 200:
		var code := RoomCode.generate(rng)
		assert_true(RoomCode.is_valid(code), code)
	for ch: String in ["I", "O", "0", "1"]:
		assert_false(RoomCode.ALPHABET.contains(ch), "no look-alike " + ch)
	assert_eq(RoomCode.ALPHABET.length(), 32)


func test_normalize_and_validate() -> void:
	assert_eq(RoomCode.normalize(" abc-234xyz "), "ABC234")
	assert_eq(RoomCode.normalize("io01ab"), "AB", "look-alikes are dropped, not guessed")
	assert_true(RoomCode.is_valid("K7QW2Z"))
	assert_false(RoomCode.is_valid("K7QW2"), "too short")
	assert_false(RoomCode.is_valid("k7qw2z"), "lower case is not a stored code")
	assert_false(RoomCode.is_valid("K7QW2O"))


func test_migration_checks_the_same_alphabet() -> void:
	var sql := FileAccess.get_file_as_string(MIGRATION)
	assert_string_contains(sql, "'^[A-HJ-NP-Z2-9]{6}$'")
	var re := RegEx.create_from_string("^[A-HJ-NP-Z2-9]{6}$")
	for ch: String in RoomCode.ALPHABET:
		assert_not_null(re.search(ch.repeat(6)), "the table accepts " + ch)
	for column: String in ["host_id", "status", "player_count", "rule", "arena", "expires_at"]:
		assert_string_contains(sql, column)
	assert_string_contains(sql, "enable row level security")
	assert_string_contains(sql, "function public.get_room(p_code text)")
	assert_string_contains(sql, "new.expires_at := old.expires_at", "hosts cannot extend a room")


func test_create_posts_a_waiting_room_with_auth_headers() -> void:
	_api.create("stock", "log_bridge", func(ok: bool, code: String, attempts: int, status: int) -> void:
		_results.append([ok, code, attempts, status]))
	var r := _http.last()
	assert_eq(r["url"], URL + "/rest/v1/rooms")
	assert_eq(r["method"], HTTPClient.METHOD_POST)
	assert_eq(_http.header(r, "Authorization"), "Bearer access-1")
	assert_eq(_http.header(r, "apikey"), "anon-key")
	assert_eq(_http.last_json(), {"code": "AAAAAA", "status": "waiting", "player_count": 1.0, "rule": "stock",
		"arena": "log_bridge"})
	_http.respond(201)
	assert_eq(_results, [[true, "AAAAAA", 1, 201]])


func test_create_retries_a_taken_code() -> void:
	_api.create("stock", "x", func(ok: bool, code: String, attempts: int, _s: int) -> void:
		_results.append([ok, code, attempts]))
	_http.respond(RoomsApi.HTTP_CONFLICT)
	_http.respond(RoomsApi.HTTP_CONFLICT)
	_http.respond(201)
	assert_eq(_results, [[true, "CCCCCC", 3]])


func test_create_gives_up_after_max_tries_or_on_other_errors() -> void:
	_api.create("stock", "x", func(ok: bool, _c: String, attempts: int, status: int) -> void:
		_results.append([ok, attempts, status]))
	for i: int in RoomsApi.MAX_CREATE_TRIES:
		_http.respond(RoomsApi.HTTP_CONFLICT)
	assert_eq(_results, [[false, RoomsApi.MAX_CREATE_TRIES, RoomsApi.HTTP_CONFLICT]])
	_results.clear()
	_api.create("stock", "x", func(ok: bool, _c: String, attempts: int, status: int) -> void:
		_results.append([ok, attempts, status]))
	_http.respond(500)
	assert_eq(_results, [[false, 1, 500]])


func test_lookup_finds_an_open_room_or_404() -> void:
	_api.lookup("K7QW2Z", func(ok: bool, row: Dictionary, status: int) -> void: _results.append([ok, row, status]))
	assert_eq(_http.last()["url"], URL + "/rest/v1/rpc/get_room", "open rooms cannot be listed: lookup is an RPC")
	assert_eq(_http.last()["method"], HTTPClient.METHOD_POST)
	assert_eq(_http.last_json(), {"p_code": "K7QW2Z"})
	_http.respond(200, JSON.stringify([{"code": "K7QW2Z", "status": "waiting", "player_count": 2}]))
	assert_true(_results[0][0])
	assert_eq(_results[0][1]["code"], "K7QW2Z")
	_api.lookup("NOPE22", func(ok: bool, row: Dictionary, status: int) -> void: _results.append([ok, row, status]))
	_http.respond(200, "[]")
	assert_eq(_results[1], [false, {}, RoomsApi.HTTP_NOT_FOUND])


func test_update_and_close_patch_by_code() -> void:
	_api.update("K7QW2Z", {"player_count": 3}, func(ok: bool, status: int) -> void: _results.append([ok, status]))
	assert_eq(_http.last()["method"], HTTPClient.METHOD_PATCH)
	assert_eq(_http.last()["url"], URL + "/rest/v1/rooms?code=eq.K7QW2Z")
	_http.respond(204)
	_api.close("K7QW2Z")
	assert_eq(_http.last_json(), {"status": "closed"})
	assert_eq(_results, [[true, 204]])


func test_no_session_makes_no_request() -> void:
	var api := RoomsApi.new(SupabaseClient.new(URL, "anon-key", _http))
	api.lookup("K7QW2Z", func(ok: bool, _row: Dictionary, status: int) -> void: _results.append([ok, status]))
	assert_eq(_results, [[false, SupabaseClient.STATUS_NO_SESSION]])
	assert_eq(_http.requests.size(), 0)
