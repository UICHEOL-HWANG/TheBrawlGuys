extends HttpTransport
## Test double: records requests and answers them only when the test calls respond().

var requests: Array[Dictionary] = []
var _pending: Array[Dictionary] = []


func request(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: String,
		done: Callable) -> void:
	var r := {"url": url, "headers": headers, "method": method, "body": body, "done": done}
	requests.append(r)
	_pending.append(r)


func pending_count() -> int:
	return _pending.size()


## Answers the oldest open request.
func respond(status: int, body: String = "{}") -> void:
	assert(not _pending.is_empty(), "FakeHttpTransport.respond: no open request")
	var r: Dictionary = _pending.pop_front()
	(r["done"] as Callable).call(status, body)


func last() -> Dictionary:
	return requests.back() if not requests.is_empty() else {}


func last_json() -> Variant:
	return JSON.parse_string(String(last().get("body", "")))


func header(r: Dictionary, name: String) -> String:
	for h: String in r["headers"]:
		if h.to_lower().begins_with(name.to_lower() + ":"):
			return h.substr(name.length() + 1).strip_edges()
	return ""
