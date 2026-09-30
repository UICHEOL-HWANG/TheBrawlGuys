class_name GodotHttpTransport
extends HttpTransport
## Real HTTP: one short-lived HTTPRequest child of the host node per call.

## Seconds before a request gives up (reported as status 0).
const TIMEOUT_S := 15.0

var _host: Node


func _init(host: Node) -> void:
	_host = host


func request(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: String,
		done: Callable) -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		push_warning("GodotHttpTransport: host node gone, request to %s skipped" % url)
		done.call(0, "")
		return
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	_host.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray) -> void:
		http.queue_free()
		done.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data.get_string_from_utf8()))
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		push_warning("GodotHttpTransport: request to %s failed to start (%s)" % [url, error_string(err)])
		done.call(0, "")
