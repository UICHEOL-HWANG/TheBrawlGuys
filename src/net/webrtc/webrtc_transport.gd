class_name WebRtcTransport
extends NetTransport
## NetTransport over raw WebRTC (Phase 6 online, star topology): the host (peer 1) holds one
## WebRtcPeerLink per client, a client holds one link to the host. Signaling (RoomSignaling) feeds
## remote descriptions / candidates in and sends out what description_ready / candidate_ready
## emit. Each message gets a one-byte kind header: data, or PING / PONG on the reliable channel,
## which give rtt_ms(). service() pumps links (connect, timeouts, pings) and queues received data;
## poll() services and drains that queue — the lobby calls service() each frame so nothing the
## host sends before the netcode takes over is lost.

signal description_ready(peer_id: int, type: String, sdp: String)
signal candidate_ready(peer_id: int, mid: String, index: int, name: String)
## A link that never opened: stage "ice" (ICE failed) or "timeout" (not open in time).
signal link_failed(peer_id: int, stage: String)

const KIND_DATA := 0
const KIND_PING := 1
const KIND_PONG := 2
const PING_INTERVAL_MS := 1_000
const CONNECT_TIMEOUT_MS := 20_000
## Weight of a new sample in the smoothed round-trip time.
const RTT_SMOOTHING := 0.25
## Received messages kept for poll(); older ones are dropped beyond this.
const MAX_QUEUE := 4_096
const STAGE_ICE := "ice"
const STAGE_TIMEOUT := "timeout"

var peer_factory: Callable = WebRtcSupport.new_peer
var clock_ms: Callable = Time.get_ticks_msec

var _local_id: int
var _ice: Dictionary
var _links: Dictionary = {}  # peer id -> WebRtcPeerLink
var _opened_ms: Dictionary = {}
var _connected: Dictionary = {}
var _rtt: Dictionary = {}
var _next_ping_ms: Dictionary = {}
var _queue: Array[Dictionary] = []


func _init(local_peer_id: int, ice: Dictionary) -> void:
	_local_id = local_peer_id
	_ice = ice


func local_id() -> int:
	return _local_id


## Client: the id the host assigned (signaling).
func set_local_id(id: int) -> void:
	_local_id = id


func peers() -> PackedInt32Array:
	return PackedInt32Array(_connected.keys())


## Starts a link to peer_id; the offerer (host) creates the offer at once.
func open_link(peer_id: int, offerer: bool) -> Error:
	if _links.has(peer_id):
		return ERR_ALREADY_EXISTS
	var link := WebRtcPeerLink.new(peer_factory.call() as Object)
	var err := link.setup(_ice)
	if err != OK:
		link_failed.emit(peer_id, STAGE_ICE)
		return err
	link.description_ready.connect(func(type: String, sdp: String) -> void:
		description_ready.emit(peer_id, type, sdp))
	link.candidate_ready.connect(func(mid: String, index: int, name: String) -> void:
		candidate_ready.emit(peer_id, mid, index, name))
	_links[peer_id] = link
	_opened_ms[peer_id] = int(clock_ms.call())
	return link.offer() if offerer else OK


## A remote offer opens the link on the answering side.
func handle_description(peer_id: int, type: String, sdp: String) -> void:
	if not _links.has(peer_id) and type == "offer":
		if open_link(peer_id, false) != OK:
			return
	if _links.has(peer_id):
		(_links[peer_id] as WebRtcPeerLink).set_remote(type, sdp)


func handle_candidate(peer_id: int, mid: String, index: int, name: String) -> void:
	if _links.has(peer_id):
		(_links[peer_id] as WebRtcPeerLink).add_candidate(mid, index, name)


func link_status(peer_id: int) -> WebRtcPeerLink.Status:
	return (_links[peer_id] as WebRtcPeerLink).status() if _links.has(peer_id) else WebRtcPeerLink.Status.CLOSED


## Closes the link to peer_id (peer_disconnected when it was connected).
func drop_peer(peer_id: int) -> void:
	if _links.has(peer_id):
		(_links[peer_id] as WebRtcPeerLink).close()
	for d: Dictionary in [_links, _opened_ms, _rtt, _next_ping_ms]:
		d.erase(peer_id)
	if _connected.erase(peer_id):
		peer_disconnected.emit(peer_id)


## Pumps every link once: state changes, pings and received data (queued for poll()).
func service() -> void:
	var now := int(clock_ms.call())
	for peer_id: int in _links.keys():
		var link: WebRtcPeerLink = _links[peer_id]
		link.poll()
		if _update_state(peer_id, link, now):
			_receive(peer_id, link, now)


func poll() -> Array[Dictionary]:
	service()
	var out := _queue
	_queue = []
	return out


func send(peer_id: int, channel: int, bytes: PackedByteArray) -> void:
	var framed := PackedByteArray([KIND_DATA])
	framed.append_array(bytes)
	for id: int in ([peer_id] if peer_id != 0 else _connected.keys()):
		if _links.has(id):
			(_links[id] as WebRtcPeerLink).send(channel, framed)


func rtt_ms(peer_id: int) -> float:
	return float(_rtt.get(peer_id, -1.0))


func close() -> void:
	for peer_id: int in _links.keys():
		drop_peer(peer_id)
	_queue.clear()


## False when the link is gone after this update.
func _update_state(peer_id: int, link: WebRtcPeerLink, now: int) -> bool:
	var status := link.status()
	if status == WebRtcPeerLink.Status.OPEN:
		if not _connected.has(peer_id):
			_connected[peer_id] = true
			_next_ping_ms[peer_id] = now
			peer_connected.emit(peer_id)
		return true
	if status == WebRtcPeerLink.Status.FAILED or status == WebRtcPeerLink.Status.CLOSED:
		var never_opened := not _connected.has(peer_id)
		drop_peer(peer_id)
		if never_opened:
			link_failed.emit(peer_id, STAGE_ICE)
		return false
	if not _connected.has(peer_id) and now - int(_opened_ms[peer_id]) > CONNECT_TIMEOUT_MS:
		drop_peer(peer_id)
		link_failed.emit(peer_id, STAGE_TIMEOUT)
		return false
	return true


func _receive(peer_id: int, link: WebRtcPeerLink, now: int) -> void:
	for channel: int in [CHANNEL_FAST, CHANNEL_RELIABLE]:
		for packet: PackedByteArray in link.drain(channel):
			_on_packet(peer_id, link, channel, packet, now)
	if _connected.has(peer_id) and now >= int(_next_ping_ms[peer_id]):
		_next_ping_ms[peer_id] = now + PING_INTERVAL_MS
		link.send(CHANNEL_RELIABLE, _stamp(KIND_PING, now))


func _on_packet(peer_id: int, link: WebRtcPeerLink, channel: int, packet: PackedByteArray, now: int) -> void:
	if packet.is_empty():
		return
	match packet[0]:
		KIND_DATA:
			_queue.append({"from": peer_id, "channel": channel, "bytes": packet.slice(1)})
			if _queue.size() > MAX_QUEUE:
				_queue.pop_front()
		KIND_PING:
			if packet.size() >= 5:
				var pong := packet.duplicate()
				pong[0] = KIND_PONG
				link.send(CHANNEL_RELIABLE, pong)
		KIND_PONG:
			if packet.size() >= 5:
				_note_rtt(peer_id, float((now - packet.decode_u32(1)) & 0xFFFFFFFF))


func _note_rtt(peer_id: int, sample: float) -> void:
	var old := float(_rtt.get(peer_id, -1.0))
	_rtt[peer_id] = sample if old < 0.0 else lerpf(old, sample, RTT_SMOOTHING)


static func _stamp(kind: int, now: int) -> PackedByteArray:
	var b := PackedByteArray([kind, 0, 0, 0, 0])
	b.encode_u32(1, now & 0xFFFFFFFF)
	return b
