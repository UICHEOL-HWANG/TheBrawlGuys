class_name RoomsApi
extends RefCounted
## Supabase `rooms` table over PostgREST (Phase 6 online, migration 0005), through the game's
## SupabaseClient (anon key + the signed-in user's token; RLS lets the host write only its rows).
## create retries with a new code when the code is taken (409); lookup finds an open room by
## code; update / close change status and player_count. Rooms expire on their own (expires_at).

const STATUS_WAITING := "waiting"
const STATUS_PLAYING := "playing"
const STATUS_CLOSED := "closed"
const MAX_CREATE_TRIES := 5
const HTTP_CONFLICT := 409
const HTTP_NOT_FOUND := 404
const LOOKUP_RPC := "rpc/get_room"

## () -> String; tests pin it.
var new_code: Callable = RoomCode.generate

var _client: SupabaseClient


func _init(client: SupabaseClient) -> void:
	_client = client


## done(ok: bool, code: String, attempts: int, status: int).
func create(rule: String, arena: String, done: Callable) -> void:
	_create_try(rule, arena, 1, done)


## done(ok: bool, row: Dictionary, status: int) — 404 when no open room has that code. Goes
## through the get_room RPC: RLS shows players only their own rows, so open rooms cannot be listed.
func lookup(code: String, done: Callable) -> void:
	_request(HTTPClient.METHOD_POST, LOOKUP_RPC, JSON.stringify({"p_code": code}),
			func(ok: bool, status: int, body: String) -> void:
		var rows: Variant = JsonSafe.parse(body) if ok else null
		if rows is Array and not (rows as Array).is_empty() and rows[0] is Dictionary:
			done.call(true, rows[0], status)
		else:
			done.call(false, {}, status if not ok else HTTP_NOT_FOUND))


## done(ok: bool, status: int). fields: status and / or player_count, rule, arena.
func update(code: String, fields: Dictionary, done: Callable = Callable()) -> void:
	_request(HTTPClient.METHOD_PATCH, "rooms?code=eq.%s" % code.uri_encode(), JSON.stringify(fields),
			func(ok: bool, status: int, _body: String) -> void:
				if done.is_valid():
					done.call(ok, status))


## "" when a looked-up room can be joined, else why not: not_found | error | started | full.
static func join_refusal(ok: bool, row: Dictionary, status: int, max_players: int) -> String:
	if not ok:
		return "not_found" if status == HTTP_NOT_FOUND else "error"
	if String(row.get("status", "")) == STATUS_PLAYING:
		return "started"
	return "full" if int(row.get("player_count", 0)) >= max_players else ""


func close(code: String, done: Callable = Callable()) -> void:
	update(code, {"status": STATUS_CLOSED}, done)


func _create_try(rule: String, arena: String, attempt: int, done: Callable) -> void:
	var code := String(new_code.call())
	var row := {"code": code, "status": STATUS_WAITING, "player_count": 1, "rule": rule, "arena": arena}
	_request(HTTPClient.METHOD_POST, "rooms", JSON.stringify(row), func(ok: bool, status: int, _b: String) -> void:
		if ok:
			done.call(true, code, attempt, status)
		elif status == HTTP_CONFLICT and attempt < MAX_CREATE_TRIES:
			_create_try(rule, arena, attempt + 1, done)
		else:
			done.call(false, "", attempt, status))


## done(ok: bool, status: int, body: String).
func _request(method: HTTPClient.Method, path: String, body: String, done: Callable) -> void:
	if not _client.has_session():
		done.call(false, SupabaseClient.STATUS_NO_SESSION, "not signed in")
		return
	_client.fresh_token(func(ok: bool, status: int, message: String) -> void:
		if not ok:
			done.call(false, status, message)
			return
		_client.transport().request("%s/rest/v1/%s" % [_client.url(), path], _headers(), method, body,
				func(code: int, text: String) -> void:
					done.call(code >= 200 and code < 300, code, text)))


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + _client.anon_key(), "Authorization: Bearer " + _client.session.access_token,
		"Content-Type: application/json", "Prefer: return=minimal",
	])
