extends GutTest
## A host and a client OnlineRoom end to end (Phase 6) over an in-memory Realtime bus, fake HTTP
## (rooms table) and fake WebRTC peers: create → join → hello / offer / answer → connected →
## picks → start (OnlineStart.begin, a stub for now) → the host leaves. Tracking stays in schema.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const FakePeer := preload("res://tests/unit/support/fake_rtc_peer.gd")
const FakeChannel := preload("res://tests/unit/support/fake_realtime_channel.gd")
const CODE := "K7QW2Z"

var _bus: Array = []
var _tracked: Array = []
var _rtc: Dictionary = {"host": [], "client": []}
var _http: Dictionary = {}
var _left: Array = []
var _notices: Array = []


func before_each() -> void:
	_bus.clear()
	_tracked.clear()
	_left.clear()
	_notices.clear()
	_rtc = {"host": [], "client": []}


func _room(tag: String) -> OnlineRoom:
	var http := FakeHttp.new()
	_http[tag] = http
	var client := SupabaseClient.new("https://proj.supabase.co", "anon", http)
	client.now_s = func() -> int: return 1_000
	client.session = SupabaseSession.new("jwt-" + tag, "r", 100_000, "user-" + tag)
	var room := OnlineRoom.new()
	autofree(room)
	room.rooms = RoomsApi.new(client)
	room.rooms.new_code = func() -> String: return CODE
	room.access_token = "jwt-" + tag
	room.clock_ms = func() -> int: return 5_000
	room.track = func(event_name: String, props: Dictionary) -> void:
		assert_eq(EventCatalog.validate(event_name, props), PackedStringArray(), event_name)
		_tracked.append([tag, event_name, props])
	room.channel_factory = func(_is_host: bool) -> RealtimeChannel:
		var ch := FakeChannel.new()
		ch.bus = _bus
		return ch
	room.peer_factory = func() -> Object:
		var p := FakePeer.new()
		(_rtc[tag] as Array).append(p)
		return p
	room.left.connect(func(reason: String, message: String) -> void: _left.append([tag, reason, message]))
	room.notice.connect(func(text: String) -> void: _notices.append([tag, text]))
	return room


func _events(tag: String) -> Array:
	return _tracked.filter(func(t: Array) -> bool: return t[0] == tag).map(func(t: Array) -> String: return t[1])


func _open_pair() -> Array[OnlineRoom]:
	var host := _room("host")
	host.create(MatchRules.STOCK, "log_bridge")
	(_http["host"] as FakeHttp).respond(201)
	var client := _room("client")
	client.join(CODE)
	(_http["client"] as FakeHttp).respond(200, JSON.stringify([{"code": CODE, "status": "waiting", "player_count": 1}]))
	FakePeer.link(_rtc["host"][0], _rtc["client"][0])
	host._process(0.0)
	client._process(0.0)
	return [host, client]


func test_create_join_connect_pick_and_start() -> void:
	var rooms := _open_pair()
	var host := rooms[0]
	var client := rooms[1]
	assert_eq(host.phase(), OnlineRoom.Phase.LOBBY)
	assert_eq(client.peers.local_id(), 2, "the host assigned id 2")
	assert_eq(client.peers.transport.local_id(), 2)
	assert_eq(host.peers.transport.peers(), PackedInt32Array([2]))
	assert_eq(host.peers.model.slots[1]["conn"], LobbyModel.CONN_CONNECTED)
	assert_eq(client.peers.model.human_count(), 2, "the client mirrors the host's lobby")
	assert_eq(client.peers.model.arena, "log_bridge")
	client.peers.pick(CharacterData.MAGE, true)
	assert_false(host.peers.model.can_start(), "the host is not ready yet")
	host.peers.pick(CharacterData.KNIGHT, true)
	assert_true(host.peers.model.can_start())
	host.start_match()
	assert_eq(_notices.size(), 2, "every device reached OnlineStart.begin (stub)")
	assert_true(_notices.has(["host", OnlineStart.PENDING_TEXT]))
	assert_true(_notices.has(["client", OnlineStart.PENDING_TEXT]))
	assert_eq(_events("host"), ["room_created", "room_joined"])
	assert_eq(_events("client"), ["room_joined"])
	var patches := (_http["host"] as FakeHttp).requests.filter(func(r: Dictionary) -> bool:
		return r["method"] == HTTPClient.METHOD_PATCH).map(func(r: Dictionary) -> String: return r["body"])
	assert_true(patches.has(JSON.stringify({"status": "playing"})))
	assert_true(patches.has(JSON.stringify({"player_count": 2})))


func test_the_host_leaving_sends_the_client_back() -> void:
	var rooms := _open_pair()
	rooms[0].leave("back")
	assert_eq(_left, [["client", "host_left", OnlineRoom.MSG["host_left"]]])
	assert_eq(_events("host").back(), "room_left")
	var client_left: Array = _tracked.filter(func(t: Array) -> bool: return t[0] == "client" and t[1] == "room_left")
	assert_eq(client_left[0][2]["reason"], "host_left")
	var closes := (_http["host"] as FakeHttp).requests.filter(func(r: Dictionary) -> bool:
		return r["body"] == JSON.stringify({"status": "closed"}))
	assert_eq(closes.size(), 1, "the host closes its rooms row")


func test_join_of_a_missing_or_playing_room() -> void:
	var client := _room("client")
	client.join("NOPE22")
	(_http["client"] as FakeHttp).respond(200, "[]")
	assert_eq(_left.back(), ["client", "not_found", OnlineRoom.MSG["not_found"]])
	client = _room("client")
	client.join(CODE)
	(_http["client"] as FakeHttp).respond(200, JSON.stringify([{"code": CODE, "status": "playing"}]))
	assert_eq(_left.back()[1], "started")
	assert_eq(_events("client"), [], "nothing joined, nothing left")


func test_a_failed_link_is_tracked_with_its_stage() -> void:
	var host := _room("host")
	host.create(MatchRules.STOCK, "log_bridge")
	(_http["host"] as FakeHttp).respond(201)
	var client := _room("client")
	client.join(CODE)
	(_http["client"] as FakeHttp).respond(200, JSON.stringify([{"code": CODE, "status": "waiting"}]))
	(_rtc["host"][0] as FakePeer).connection_state = WebRTCPeerConnection.STATE_FAILED
	host._process(0.0)
	var failed: Array = _tracked.filter(func(t: Array) -> bool: return t[1] == "peer_connect_failed")
	assert_eq(failed[0][2]["stage"], "ice")
	assert_eq(host.peers.model.human_count(), 1, "the seat is freed, start is not blocked forever")
	assert_eq(_left.back(), ["client", "error", OnlineRoom.MSG["error"]], "the client is told")


func test_a_lost_host_link_sends_the_client_back() -> void:
	var rooms := _open_pair()
	(_rtc["client"][0] as FakePeer).connection_state = WebRTCPeerConnection.STATE_CLOSED
	rooms[1]._process(0.0)
	assert_eq(_left.back().slice(0, 2), ["client", "host_left"])


func test_late_hello_after_start_is_turned_away() -> void:
	var rooms := _open_pair()
	rooms[1].peers.pick(CharacterData.MAGE, true)
	rooms[0].peers.pick(CharacterData.KNIGHT, true)
	rooms[0].peers.locked = true
	var late := _room("late")
	_rtc["late"] = []
	late.join(CODE)
	(_http["late"] as FakeHttp).respond(200, JSON.stringify([{"code": CODE, "status": "waiting"}]))
	assert_eq(_left.back().slice(0, 2), ["late", "started"])
	assert_eq(rooms[0].peers.model.human_count(), 2)


func test_a_full_room_turns_the_fifth_player_away() -> void:
	var host := _room("host")
	host.create(MatchRules.STOCK, "log_bridge")
	(_http["host"] as FakeHttp).respond(201)
	host.peers.model.add_human(7)
	host.peers.model.add_human(8)
	host.peers.model.add_human(9)
	var client := _room("client")
	client.join(CODE)
	(_http["client"] as FakeHttp).respond(200, JSON.stringify([{"code": CODE, "status": "waiting", "player_count": 3}]))
	assert_eq(_left.back(), ["client", "full", OnlineRoom.MSG["full"]])
