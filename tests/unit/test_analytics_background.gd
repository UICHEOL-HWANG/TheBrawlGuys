extends GutTest
## Leaving the page / background (event schema 8 tracking fixes): the web page hands its queue to
## navigator.sendBeacon in batches the browser accepts, an open request is abandoned without
## losing events, and a long absence starts a new Amplitude session.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")

var _http: FakeHttp
var _client: AnalyticsClient
var _beacons: Array[String] = []
var _accept: int = 999


func before_each() -> void:
	_http = FakeHttp.new()
	_beacons.clear()
	_accept = 999
	_client = AnalyticsClient.new("test-key", "device-1", _http, BatchQueue.new("", 200))
	_client.clock_ms = func() -> int: return 0
	_client.wall_ms = func() -> int: return 1_000


func _beacon(url: String, body: String) -> bool:
	assert_eq(url, AnalyticsClient.ENDPOINT)
	if _beacons.size() >= _accept:
		return false
	_beacons.append(body)
	return true


func _queue_screens(n: int) -> void:
	for i: int in n:
		_client.track("screen_viewed", {"screen": "s%d" % i})


func test_beacon_sends_everything_queued_in_small_batches() -> void:
	_queue_screens(AnalyticsClient.BEACON_MAX_EVENTS + 5)  # the 20th event opens a request
	assert_true(_client.in_flight())
	_client.track("session_ended", {"duration_s": 3.0, "matches": 1, "last_screen": "match"})
	var handed := _client.beacon_flush(_beacon)
	assert_eq(handed, AnalyticsClient.BEACON_MAX_EVENTS + 6, "the in-flight batch goes too")
	assert_eq(_beacons.size(), 2)
	assert_eq(_client.queued(), 0)
	assert_false(_client.in_flight())
	var last: Dictionary = JSON.parse_string(_beacons[1])
	assert_eq(last["api_key"], "test-key")
	assert_eq((last["events"] as Array).back()["event_type"], "session_ended")


func test_a_late_answer_of_the_abandoned_request_is_ignored() -> void:
	_queue_screens(AnalyticsClient.FLUSH_COUNT)
	_client.beacon_flush(_beacon)
	_queue_screens(3)
	_http.respond(200)
	assert_eq(_client.queued(), 3, "the stale 200 drops nothing that came after")


func test_refused_beacons_keep_the_events_for_next_visit() -> void:
	_queue_screens(AnalyticsClient.BEACON_MAX_EVENTS + 5)
	_accept = 1
	assert_eq(_client.beacon_flush(_beacon), AnalyticsClient.BEACON_MAX_EVENTS)
	assert_eq(_client.queued(), 5)


func test_long_absence_renews_the_session() -> void:
	assert_false(SessionTracker.is_new_session(SessionTracker.SESSION_TIMEOUT_MS - 1))
	assert_true(SessionTracker.is_new_session(SessionTracker.SESSION_TIMEOUT_MS))
	var before := _client.session_id
	_client.wall_ms = func() -> int: return 5_000_000
	_client.renew_session()
	assert_ne(_client.session_id, before)
	assert_eq(_client.session_id, 5_000_000)


func test_web_lifecycle_is_inert_off_the_web() -> void:
	var web := WebLifecycle.new()
	assert_false(web.attach(func() -> void: pass, func() -> void: pass))
	assert_false(WebLifecycle.send_beacon(AnalyticsClient.ENDPOINT, "{}"))
