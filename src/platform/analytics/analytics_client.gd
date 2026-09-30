class_name AnalyticsClient
extends RefCounted
## Amplitude sender (platform A2): validates against EventCatalog, batches (FLUSH_COUNT events or
## FLUSH_INTERVAL_MS), one request at a time, retries transient failures with backoff and keeps
## unsent events in the offline BatchQueue. Pure logic: transport and clocks are injected.

const ENDPOINT := "https://api2.amplitude.com/2/httpapi"
const FLUSH_COUNT := 20
const FLUSH_INTERVAL_MS := 10_000
const MAX_EVENTS_PER_REQUEST := 100
const HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept: */*"]
const HTTP_TOO_MANY_REQUESTS := 429
const HTTP_SERVER_ERROR := 500
## An open request older than this is treated as lost (transport timeout is 15 s).
const IN_FLIGHT_TIMEOUT_MS := 30_000

## Monotonic milliseconds (batch timer, backoff).
var clock_ms: Callable = Time.get_ticks_msec
## Unix epoch milliseconds (event time).
var wall_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
## Top-level Amplitude fields for every event (PlatformEnv.amplitude_context()).
var context: Dictionary = {}
var session_id: int = 0

var _api_key: String
var _device_id: String
var _user_id: String = ""
var _transport: HttpTransport
var _queue: BatchQueue
var _super: Dictionary = {}
var _user_props: Dictionary = {}
var _seq: int = 0
var _sending: int = 0
var _dropped_at_send: int = 0
var _request_id: int = 0
var _last_send_ms: int = 0


func _init(api_key: String, device_id: String, transport: HttpTransport, queue: BatchQueue) -> void:
	_api_key = api_key
	_device_id = device_id
	_transport = transport
	_queue = queue
	session_id = int(wall_ms.call())
	_queue.restore()


## Queues a catalog event; returns false (and reports) when it is invalid.
func track(event_name: String, props: Dictionary = {}) -> bool:
	var errors := EventCatalog.validate(event_name, props)
	if not errors.is_empty():
		report_invalid(errors)
		return false
	var merged := _super.merged(props, true)
	_seq += 1
	var identity := {"device_id": _device_id, "user_id": _user_id, "session_id": session_id}
	var insert_id := "%s-%d-%d" % [_device_id, session_id, _seq]
	_queue.push(AmplitudePayload.event(event_name, merged, identity, int(wall_ms.call()), insert_id,
			context, _user_props))
	poll()
	return true


func identify(user_id: String, user_props: Dictionary = {}) -> void:
	_user_id = user_id
	_user_props = user_props.duplicate(true)


## A property added to every later event (quality, input_device, ...).
func set_super_property(key: String, value: Variant) -> void:
	_super[key] = value


## Sends when a batch is full or the interval passed; call every frame.
func poll() -> void:
	var now := int(clock_ms.call())
	if _queue.size() >= FLUSH_COUNT or now - _last_send_ms >= FLUSH_INTERVAL_MS:
		flush()


## Sends what is queued now (match end, app pause), unless a request is open or backing off.
func flush() -> void:
	var now := int(clock_ms.call())
	if _sending > 0 and now - _last_send_ms >= IN_FLIGHT_TIMEOUT_MS:
		_sending = 0  # the answer was lost (host freed, dropped socket); a late one is ignored
	if _sending > 0 or _queue.size() == 0 or not _queue.can_send(now):
		return
	var batch := _queue.peek(MAX_EVENTS_PER_REQUEST)
	_sending = batch.size()
	_dropped_at_send = _queue.dropped_count()
	_last_send_ms = now
	_request_id += 1
	var id := _request_id
	_transport.request(ENDPOINT, HEADERS, HTTPClient.METHOD_POST, AmplitudePayload.body(_api_key, batch),
			func(status: int, body: String) -> void:
				if id == _request_id and _sending > 0:
					_on_response(status, body))


func persist() -> void:
	_queue.save()


func queued() -> int:
	return _queue.size()


func in_flight() -> bool:
	return _sending > 0


func _on_response(status: int, body: String) -> void:
	var sent := _sending
	_sending = 0
	# Events of this batch the cap already pushed out while the request was open.
	var still_queued := maxi(sent - (_queue.dropped_count() - _dropped_at_send), 0)
	if status >= 200 and status < 300:
		_queue.drop_front(still_queued)
		_queue.mark_success()
	elif status == 0 or status == HTTP_TOO_MANY_REQUESTS or status >= HTTP_SERVER_ERROR:
		_queue.mark_failure(int(clock_ms.call()))
	else:
		push_error("AnalyticsClient: Amplitude rejected %d events (HTTP %d): %s" % [sent, status, body.left(300)])
		_queue.drop_front(still_queued)
	_queue.save()


## Debug builds fail loudly (tests catch it); release builds warn. The event is dropped either way.
static func report_invalid(errors: PackedStringArray) -> void:
	var msg := "Analytics: invalid event dropped — %s" % "; ".join(errors)
	if OS.is_debug_build():
		push_error(msg)
	else:
		push_warning(msg)
