class_name GodotHttpTransport
extends HttpTransport
## Real HTTP: one short-lived HTTPRequest child of the host node per call.
## The child is added deferred and the request starts once it is in the tree: a call made while
## the host is still setting up its children (the web sign-in exchange during App._ready) would
## otherwise fail to add_child (it starts on ready, from a static function so the request does not
## depend on this transport object staying alive). Results — failures included — always arrive
## after request() returns, so a screen shown right after the call still hears them.

## Seconds before a request gives up (reported as status 0).
const TIMEOUT_S := 15.0

var _host: Node


func _init(host: Node) -> void:
	_host = host


func request(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: String,
		done: Callable) -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		push_warning("GodotHttpTransport: host node gone, request to %s skipped" % url)
		done.call_deferred(0, "")
		return
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray) -> void:
		http.queue_free()
		done.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data.get_string_from_utf8()))
	http.ready.connect(_start.bind(http, url, headers, method, body, done), CONNECT_ONE_SHOT)
	_host.add_child.call_deferred(http)


static func _start(http: HTTPRequest, url: String, headers: PackedStringArray, method: HTTPClient.Method,
		body: String, done: Callable) -> void:
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		push_warning("GodotHttpTransport: request to %s failed to start (%s)" % [url, error_string(err)])
		done.call_deferred(0, "")
