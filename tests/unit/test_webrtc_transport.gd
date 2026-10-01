extends GutTest
## WebRtcTransport (Phase 6) over fake peer connections: the two negotiated channels, offer /
## answer / ICE plumbing, connect and failure detection, framing, broadcast and rtt.

const FakePeer := preload("res://tests/unit/support/fake_rtc_peer.gd")
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}

var _now: int = 0
var _host: WebRtcTransport
var _client: WebRtcTransport
var _host_peers: Array = []
var _client_peers: Array = []
var _log: Array = []


func before_each() -> void:
	_now = 1000
	_log.clear()
	_host_peers.clear()
	_client_peers.clear()
	_host = _transport(1, _host_peers, "host")
	_client = _transport(2, _client_peers, "client")


func _transport(id: int, made: Array, tag: String) -> WebRtcTransport:
	var t := WebRtcTransport.new(id, ICE)
	t.clock_ms = func() -> int: return _now
	t.peer_factory = func() -> Object:
		var p := FakePeer.new()
		made.append(p)
		return p
	t.peer_connected.connect(func(p: int) -> void: _log.append([tag, "connected", p]))
	t.peer_disconnected.connect(func(p: int) -> void: _log.append([tag, "disconnected", p]))
	t.link_failed.connect(func(p: int, stage: String) -> void: _log.append([tag, "failed", p, stage]))
	return t


## Host offers to the client (through a direct "signaling" hop), then the fakes link up.
func _connect() -> void:
	_host.description_ready.connect(func(_p: int, type: String, sdp: String) -> void:
		_client.handle_description(1, type, sdp))
	_client.description_ready.connect(func(_p: int, type: String, sdp: String) -> void:
		_host.handle_description(2, type, sdp))
	_host.open_link(2, true)
	FakePeer.link(_host_peers[0], _client_peers[0])
	_host.service()
	_client.service()


func test_two_negotiated_channels_with_the_spec_options() -> void:
	_host.open_link(2, true)
	var peer: FakePeer = _host_peers[0]
	assert_eq(peer.ice, ICE)
	assert_eq(peer.options.size(), 2)
	assert_eq(peer.options[NetTransport.CHANNEL_FAST],
			{"negotiated": true, "id": 0, "maxRetransmits": 0, "ordered": true}, "fast: unreliable ordered")
	assert_eq(peer.options[NetTransport.CHANNEL_RELIABLE], {"negotiated": true, "id": 1, "ordered": true},
			"reliable: reliable ordered")


func test_offer_answer_and_ice_plumbing() -> void:
	var out: Array = []
	_host.description_ready.connect(func(p: int, type: String, sdp: String) -> void: out.append([p, type, sdp]))
	_host.candidate_ready.connect(func(p: int, mid: String, i: int, n: String) -> void: out.append([p, mid, i, n]))
	_host.open_link(2, true)
	var peer: FakePeer = _host_peers[0]
	assert_eq(out, [[2, "offer", "sdp-offer"]])
	assert_eq(peer.local, [["offer", "sdp-offer"]], "the local description is set")
	peer.ice_candidate_created.emit("0", 0, "cand")
	assert_eq(out.back(), [2, "0", 0, "cand"])
	_host.handle_candidate(2, "0", 0, "remote-cand")
	assert_eq(peer.candidates, [["0", 0, "remote-cand"]])
	_client.handle_description(1, "offer", "sdp-offer")
	assert_eq((_client_peers[0] as FakePeer).remote, [["offer", "sdp-offer"]], "a remote offer opens the link")


func test_connect_send_poll_and_broadcast() -> void:
	_connect()
	assert_eq(_log, [["host", "connected", 2], ["client", "connected", 1]])
	assert_eq(_host.peers(), PackedInt32Array([2]))
	_host.send(2, NetTransport.CHANNEL_FAST, PackedByteArray([7, 8]))
	_host.send(0, NetTransport.CHANNEL_RELIABLE, PackedByteArray([9]))
	var got := _client.poll()
	assert_eq(got.size(), 2, "pings and pongs are not handed out")
	assert_eq(got[0], {"from": 1, "channel": NetTransport.CHANNEL_FAST, "bytes": PackedByteArray([7, 8])})
	assert_eq(got[1], {"from": 1, "channel": NetTransport.CHANNEL_RELIABLE, "bytes": PackedByteArray([9])})
	assert_eq(_client.poll(), [], "drained")


func test_service_keeps_messages_for_the_next_poll() -> void:
	_connect()
	_host.send(2, NetTransport.CHANNEL_RELIABLE, PackedByteArray([1]))
	_client.service()
	_client.service()
	assert_eq(_client.poll().size(), 1, "queued by service, handed out by poll")


func test_rtt_from_ping_pong_on_the_reliable_channel() -> void:
	_connect()
	assert_eq(_host.rtt_ms(2), -1.0, "unknown before the first pong")
	_now += 40
	_client.service()
	_host.service()
	assert_eq(_host.rtt_ms(2), 40.0)
	var sent: Array = ((_host_peers[0] as FakePeer).channels[NetTransport.CHANNEL_RELIABLE]).get("sent")
	assert_eq(int((sent[0] as PackedByteArray)[0]), WebRtcTransport.KIND_PING, "pings ride the reliable channel")


func test_failed_ice_and_timeout_report_link_failed() -> void:
	_host.open_link(2, true)
	(_host_peers[0] as FakePeer).connection_state = WebRTCPeerConnection.STATE_FAILED
	_host.service()
	assert_eq(_log, [["host", "failed", 2, "ice"]])
	_host.open_link(3, true)
	_now += WebRtcTransport.CONNECT_TIMEOUT_MS + 1
	_host.service()
	assert_eq(_log.back(), ["host", "failed", 3, "timeout"])
	assert_eq(_host.link_status(3), WebRtcPeerLink.Status.CLOSED)


func test_a_connected_peer_that_drops_is_disconnected() -> void:
	_connect()
	(_host_peers[0] as FakePeer).connection_state = WebRTCPeerConnection.STATE_CLOSED
	_host.service()
	assert_eq(_log.back(), ["host", "disconnected", 2])
	assert_eq(_host.peers().size(), 0)


func test_close_drops_every_link() -> void:
	_connect()
	_host.close()
	assert_true((_host_peers[0] as FakePeer).closed)
	assert_eq(_host.peers().size(), 0)


func test_support_and_ice_config() -> void:
	assert_eq(WebRtcSupport.available(), OS.has_feature("web") or ClassDB.class_exists("WebRTCLibPeerConnection"))
	var s := Secrets.new()
	assert_eq(WebRtcSupport.ice_config(s), {"iceServers": [{"urls": [Secrets.DEFAULT_STUN]}]})
	s.turn_urls = PackedStringArray(["turn:t.example:3478"])
	s.turn_username = "u"
	s.turn_credential = "c"
	var servers: Array = WebRtcSupport.ice_config(s)["iceServers"]
	assert_eq(servers[1], {"urls": ["turn:t.example:3478"], "username": "u", "credential": "c"})
