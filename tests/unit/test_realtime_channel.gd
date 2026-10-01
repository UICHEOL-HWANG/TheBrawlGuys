extends GutTest
## Supabase Realtime over Phoenix (Phase 6 signaling): frame encode / decode, join with the user's
## token, broadcast both ways, the 25 s heartbeat and every way the channel fails.

const FakeWs := preload("res://tests/unit/support/fake_ws_port.gd")
const TOPIC := "realtime:room:ABC234"

var _ws: FakeWs
var _ch: RealtimeChannel
var _events: Array = []


func before_each() -> void:
	_ws = FakeWs.new()
	_ch = RealtimeChannel.new(_ws)
	_events.clear()
	_ch.joined.connect(func() -> void: _events.append(["joined"]))
	_ch.failed.connect(func(reason: String) -> void: _events.append(["failed", reason]))
	_ch.message.connect(func(event: String, payload: Dictionary) -> void: _events.append([event, payload]))


func _join(now: int = 0) -> void:
	_ch.open("wss://x/realtime/v1/websocket", TOPIC, "jwt-1", now)
	_ws.socket_state = WsPort.State.OPEN
	_ch.poll(now)
	var ref := String(_ws.last()["ref"])
	_ws.push(PhoenixMessage.encode(TOPIC, "phx_reply", {"status": "ok", "response": {}}, ref, ref))
	_ch.poll(now)


func test_encode_decode_round_trip() -> void:
	var text := PhoenixMessage.encode(TOPIC, "broadcast", {"a": 1}, "7", "3")
	var d: Dictionary = JSON.parse_string(text)
	assert_eq(d["join_ref"], "3")
	var msg := PhoenixMessage.decode(text)
	assert_eq([msg["topic"], msg["event"], msg["ref"]], [TOPIC, "broadcast", "7"])
	assert_eq(int((msg["payload"] as Dictionary)["a"]), 1)
	assert_eq(PhoenixMessage.decode("not json"), {})
	assert_eq(PhoenixMessage.decode("[1,2]"), {})
	assert_null(JSON.parse_string(PhoenixMessage.heartbeat("9"))["join_ref"], "no join_ref on heartbeats")


func test_socket_url_and_topic() -> void:
	assert_eq(PhoenixMessage.socket_url("https://proj.supabase.co/", "anon"),
			"wss://proj.supabase.co/realtime/v1/websocket?apikey=anon&vsn=1.0.0")
	assert_eq(PhoenixMessage.topic_for("room:ABC234"), TOPIC)


func test_join_sends_broadcast_config_and_token() -> void:
	_ch.open("wss://x", TOPIC, "jwt-1", 0)
	assert_eq(_ch.state(), RealtimeChannel.State.CONNECTING)
	_ch.poll(0)
	assert_eq(_ws.sent.size(), 0, "nothing before the socket opens")
	_ws.socket_state = WsPort.State.OPEN
	_ch.poll(0)
	var join := _ws.last()
	assert_eq([join["topic"], join["event"]], [TOPIC, "phx_join"])
	var p: Dictionary = join["payload"]
	assert_eq(p["access_token"], "jwt-1")
	assert_eq((p["config"] as Dictionary)["broadcast"], {"self": false, "ack": false})


func test_ok_reply_joins_and_broadcasts_flow_both_ways() -> void:
	_join()
	assert_eq(_events, [["joined"]])
	assert_true(_ch.broadcast("offer", {"sdp": "x"}))
	var out := _ws.last()
	assert_eq(out["event"], "broadcast")
	assert_eq((out["payload"] as Dictionary)["event"], "offer")
	assert_eq(((out["payload"] as Dictionary)["payload"] as Dictionary)["sdp"], "x")
	_ws.push(PhoenixMessage.broadcast(TOPIC, "answer", {"sdp": "y"}, "", ""))
	_ch.poll(10)
	assert_eq(_events[1], ["answer", {"sdp": "y"}])


func test_broadcast_before_join_is_refused() -> void:
	assert_false(_ch.broadcast("hello", {}))


func test_heartbeat_every_25_seconds_and_a_missed_reply_fails() -> void:
	_join(1000)
	_ws.sent.clear()
	_ch.poll(1000 + RealtimeChannel.HEARTBEAT_MS - 1)
	assert_eq(_ws.sent.size(), 0, "not yet")
	_ch.poll(1000 + RealtimeChannel.HEARTBEAT_MS)
	var hb := _ws.last()
	assert_eq([hb["topic"], hb["event"]], ["phoenix", "heartbeat"])
	_ws.push(PhoenixMessage.encode("phoenix", "phx_reply", {"status": "ok"}, String(hb["ref"])))
	_ch.poll(1000 + RealtimeChannel.HEARTBEAT_MS + 5)
	_ch.poll(1000 + RealtimeChannel.HEARTBEAT_MS * 2)
	assert_eq(_ws.events().count("heartbeat"), 2, "answered: the next one goes out")
	_ch.poll(1000 + RealtimeChannel.HEARTBEAT_MS * 3)
	assert_eq(_events.back(), ["failed", RealtimeChannel.REASON_HEARTBEAT])
	assert_eq(_ch.state(), RealtimeChannel.State.CLOSED)


func test_join_timeout_refusal_and_dropped_socket_fail() -> void:
	_ch.open("wss://x", TOPIC, "", 0)
	_ch.poll(RealtimeChannel.JOIN_TIMEOUT_MS)
	assert_eq(_events.back(), ["failed", RealtimeChannel.REASON_TIMEOUT])
	before_each()
	_ch.open("wss://x", TOPIC, "", 0)
	_ws.socket_state = WsPort.State.OPEN
	_ch.poll(0)
	var ref := String(_ws.last()["ref"])
	_ws.push(PhoenixMessage.encode(TOPIC, "phx_reply", {"status": "error", "response": {}}, ref, ref))
	_ch.poll(1)
	assert_eq(_events.back(), ["failed", RealtimeChannel.REASON_JOIN])
	before_each()
	_join()
	_ws.socket_state = WsPort.State.CLOSED
	_ch.poll(2)
	assert_eq(_events.back(), ["failed", RealtimeChannel.REASON_SOCKET])


func test_close_leaves_the_channel() -> void:
	_join()
	_ch.close()
	assert_eq(_ws.events()[_ws.events().size() - 1], "phx_leave")
	assert_eq(_ch.state(), RealtimeChannel.State.CLOSED)
	assert_false(_ch.broadcast("x", {}))


func test_frames_for_other_topics_are_ignored() -> void:
	_join()
	_ws.push(PhoenixMessage.broadcast("realtime:room:OTHER2", "offer", {}, "", ""))
	_ch.poll(1)
	assert_eq(_events.size(), 1, "only the join")
