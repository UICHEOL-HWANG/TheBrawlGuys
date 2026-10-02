class_name ProfileApi
extends RefCounted
## The signed-in player's row in Supabase public.profiles (PRD-DATA-04): display_name read for the
## nickname prefill and written when the player picks a nickname. Row-level security limits both
## to the player's own row. Needs a session; without one nothing is sent.

const ENDPOINT := "rest/profiles"

var _client: SupabaseClient


func _init(client: SupabaseClient) -> void:
	_client = client


## done(ok: bool, display_name: String); ("" when there is no row or the request failed).
func fetch(done: Callable) -> void:
	_send(HTTPClient.METHOD_GET, "select=display_name&", "", func(ok: bool, body: String) -> void:
		var rows: Variant = JsonSafe.parse(body) if ok else null
		var name := ""
		if rows is Array and not (rows as Array).is_empty() and (rows as Array)[0] is Dictionary:
			name = String(((rows as Array)[0] as Dictionary).get("display_name", ""))
		done.call(ok, name))


## done(ok: bool, display_name: String) with the name that was sent.
func save(display_name: String, done: Callable) -> void:
	_send(HTTPClient.METHOD_PATCH, "", JSON.stringify({"display_name": display_name}),
			func(ok: bool, _body: String) -> void: done.call(ok, display_name))


## then(ok: bool, body: String) after the request on the player's own row.
func _send(method: HTTPClient.Method, query: String, body: String, then: Callable) -> void:
	if _client.session == null:
		then.call(false, "")
		return
	_client.fresh_token(func(ok: bool, _status: int, _message: String) -> void:
		if not ok or _client.session == null:
			then.call(false, "")
			return
		var url := "%s/rest/v1/profiles?%sid=eq.%s" % [_client.url(), query, _client.session.user_id.uri_encode()]
		_client.transport().request(url, _headers(), method, body, func(code: int, response: String) -> void:
			var good := code >= 200 and code < 300
			if not good and (code == 0 or code >= SupabaseClient.HTTP_SERVER_ERRORS_FROM):
				_client.net_error_sink.call(ENDPOINT, code)
			then.call(good, response)))


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + _client.anon_key(), "Authorization: Bearer " + _client.session.access_token,
		"Content-Type: application/json", "Prefer: return=minimal",
	])
