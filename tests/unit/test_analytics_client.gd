extends GutTest
## Amplitude batching client (platform A2): 20 events or 10 s, v2 payload, retry, invalid drop.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const QUEUE_PATH := "user://test_analytics_client_queue.json"
const DEVICE_PATH := "user://test_device.cfg"

var _http: FakeHttp
var _now: int = 0
var _client: AnalyticsClient


func before_each() -> void:
	_now = 0
	_http = FakeHttp.new()
	_client = _make_client()


func after_each() -> void:
	for p: String in [QUEUE_PATH, DEVICE_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _make_client() -> AnalyticsClient:
	var c := AnalyticsClient.new("test-key", "device-1", _http, BatchQueue.new(QUEUE_PATH, 50))
	c.clock_ms = func() -> int: return _now
	c.wall_ms = func() -> int: return 1_700_000_000_000 + _now
	c.session_id = 1_700_000_000_000
	c.context = {"platform": "desktop", "os_name": "macOS", "app_version": "0.4.0", "language": "ko"}
	return c


func _screen(i: int) -> void:
	assert_true(_client.track("screen_viewed", {"screen": "s%d" % i}))


func test_below_threshold_waits() -> void:
	for i: int in AnalyticsClient.FLUSH_COUNT - 1:
		_screen(i)
	_client.poll()
	assert_eq(_http.requests.size(), 0)


func test_twenty_events_send_one_batch() -> void:
	for i: int in AnalyticsClient.FLUSH_COUNT:
		_screen(i)
	assert_eq(_http.requests.size(), 1)
	var r := _http.last()
	assert_eq(r["url"], AnalyticsClient.ENDPOINT)
	assert_eq(r["method"], HTTPClient.METHOD_POST)
	assert_eq(_http.header(r, "Content-Type"), "application/json")
	var body: Dictionary = _http.last_json()
	assert_eq(body["api_key"], "test-key")
	assert_eq((body["events"] as Array).size(), AnalyticsClient.FLUSH_COUNT)


func test_interval_sends_a_partial_batch() -> void:
	_screen(0)
	_now = AnalyticsClient.FLUSH_INTERVAL_MS - 1
	_client.poll()
	assert_eq(_http.requests.size(), 0)
	_now = AnalyticsClient.FLUSH_INTERVAL_MS
	_client.poll()
	assert_eq(_http.requests.size(), 1)


func test_flush_sends_now() -> void:
	_screen(0)
	_client.flush()
	assert_eq(_http.requests.size(), 1)


func test_event_payload_fields() -> void:
	_client.set_super_property("quality", "high")
	_client.identify("user-uuid-1234")
	_client.track("screen_viewed", {"screen": "title"})
	_client.track("screen_viewed", {"screen": "arena"})
	_client.flush()
	var events: Array = (_http.last_json() as Dictionary)["events"]
	var e: Dictionary = events[0]
	assert_eq(e["event_type"], "screen_viewed")
	assert_eq(e["device_id"], "device-1")
	assert_eq(e["user_id"], "user-uuid-1234")
	assert_eq(int(e["session_id"]), 1_700_000_000_000)
	assert_eq(int(e["time"]), 1_700_000_000_000)
	assert_eq(e["platform"], "desktop")
	assert_eq(e["os_name"], "macOS")
	assert_eq(e["app_version"], "0.4.0")
	assert_eq(e["event_properties"]["screen"], "title")
	assert_eq(e["event_properties"]["quality"], "high", "super properties ride along")
	assert_ne(e["insert_id"], (events[1] as Dictionary)["insert_id"], "insert_id deduplicates")


func test_anonymous_events_have_no_user_id() -> void:
	_screen(0)
	_client.flush()
	var e: Dictionary = ((_http.last_json() as Dictionary)["events"] as Array)[0]
	assert_false(e.has("user_id"))


func test_invalid_event_is_dropped_with_an_error() -> void:
	assert_false(_client.track("screen_viewed", {}))
	assert_push_error("screen")
	assert_false(_client.track("not_in_catalog", {}))
	assert_push_error("not_in_catalog")
	assert_eq(_client.queued(), 0)


func test_success_empties_the_queue() -> void:
	_screen(0)
	_client.flush()
	_http.respond(200)
	assert_eq(_client.queued(), 0)
	assert_false(_client.in_flight())


func test_failure_keeps_events_and_backs_off() -> void:
	_screen(0)
	_client.flush()
	_http.respond(0, "")
	assert_eq(_client.queued(), 1, "kept for retry")
	_client.flush()
	assert_eq(_http.requests.size(), 1, "backoff holds the retry")
	_now += BatchQueue.BACKOFF_BASE_MS
	_client.flush()
	assert_eq(_http.requests.size(), 2)
	_http.respond(503)
	assert_eq(_client.queued(), 1)
	assert_true(FileAccess.file_exists(QUEUE_PATH), "persisted while offline")


func test_bad_request_drops_the_batch() -> void:
	_screen(0)
	_client.flush()
	_http.respond(400, "{\"error\":\"invalid\"}")
	assert_push_error("400")
	assert_eq(_client.queued(), 0)


func test_one_request_at_a_time() -> void:
	_screen(0)
	_client.flush()
	_screen(1)
	_client.flush()
	assert_eq(_http.requests.size(), 1)
	_http.respond(200)
	_client.flush()
	assert_eq(_http.requests.size(), 2)
	assert_eq(((_http.last_json() as Dictionary)["events"] as Array).size(), 1, "only the unsent event")


func test_offline_queue_survives_a_restart() -> void:
	_screen(0)
	_screen(1)
	_client.persist()
	var fresh := _make_client()
	assert_eq(fresh.queued(), 2)


func test_device_id_is_created_once() -> void:
	var a := DeviceId.load_or_create(DEVICE_PATH)
	var b := DeviceId.load_or_create(DEVICE_PATH)
	assert_eq(a, b)
	assert_eq(a.length(), 36)


func test_uuid_v4_format() -> void:
	var bytes := PackedByteArray()
	bytes.resize(16)
	assert_eq(Uuid.v4(bytes), "00000000-0000-4000-8000-000000000000")
	assert_ne(Uuid.v4(), Uuid.v4())


func test_autoload_is_disabled_headless_but_still_validates() -> void:
	var analytics: Node = get_tree().root.get_node("Analytics")
	assert_false(analytics.call("is_enabled"), "no network from tests or headless runs")
	analytics.call("track", "made_up_event", {})
	assert_push_error("made_up_event")
