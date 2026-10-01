class_name LoopbackHub
extends RefCounted
## In-memory network for tests and local debugging (online design: LoopbackTransport): one host
## (peer 1) and up to MAX_CLIENTS clients in a star, every message passing through a NetDelayLine
## (latency, jitter, fast-channel loss). Time only moves with advance(), so tests are exact.
## Endpoints are held weakly (no reference cycle); keep the transports you use.

const HOST_ID := 1
const MAX_CLIENTS := 3

var line: NetDelayLine
var _now_ms: float = 0.0
## peer id -> WeakRef(LoopbackTransport)
var _endpoints: Dictionary = {}
var _next_id: int = HOST_ID + 1


func _init(p_seed: int = 0) -> void:
	line = NetDelayLine.new(p_seed)


func set_conditions(latency_ms: float, jitter_ms: float = 0.0, loss_pct: float = 0.0) -> void:
	line.latency_ms = latency_ms
	line.jitter_ms = jitter_ms
	line.loss_pct = loss_pct


func now_ms() -> float:
	return _now_ms


func advance(ms: float) -> void:
	_now_ms += maxf(ms, 0.0)


func host() -> LoopbackTransport:
	var t := _endpoint(HOST_ID)
	if t == null:
		t = LoopbackTransport.new(self, HOST_ID)
		_endpoints[HOST_ID] = weakref(t)
	return t


## A new client connected to the host, or null when the room is full.
func join() -> LoopbackTransport:
	if _client_ids().size() >= MAX_CLIENTS:
		return null
	var id := _next_id
	_next_id += 1
	var t := LoopbackTransport.new(self, id)
	_endpoints[id] = weakref(t)
	var h := _endpoint(HOST_ID)
	if h != null:
		h.peer_connected.emit(id)
	t.peer_connected.emit(HOST_ID)
	return t


## peer_id leaves: its in-flight messages vanish and the other side sees peer_disconnected.
func disconnect_peer(peer_id: int) -> void:
	if not _endpoints.has(peer_id):
		return
	var others := peers_of(peer_id)
	_endpoints.erase(peer_id)
	line.drop_peer(peer_id)
	for other: int in others:
		var t := _endpoint(other)
		if t != null:
			t.peer_disconnected.emit(peer_id)


func peers_of(peer_id: int) -> PackedInt32Array:
	if not _endpoints.has(peer_id):
		return PackedInt32Array()
	if peer_id == HOST_ID:
		return _client_ids()
	return PackedInt32Array([HOST_ID]) if _endpoints.has(HOST_ID) else PackedInt32Array()


## Queues bytes from `from` to `to` (0 = every peer of `from`).
func route(from: int, to: int, channel: int, bytes: PackedByteArray) -> void:
	var reachable := peers_of(from)
	var targets := reachable if to == 0 else PackedInt32Array([to])
	for target: int in targets:
		if reachable.has(target):
			line.push(_now_ms, from, target, channel, bytes)


func deliver(to: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in line.pop_due(_now_ms, to):
		out.append({"from": int(m["from"]), "channel": int(m["channel"]), "bytes": m["bytes"]})
	return out


func rtt_ms() -> float:
	return 2.0 * line.latency_ms + line.jitter_ms


func _client_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for id: int in _endpoints:
		if id != HOST_ID:
			ids.append(id)
	ids.sort()
	return ids


func _endpoint(id: int) -> LoopbackTransport:
	var ref: WeakRef = _endpoints.get(id)
	return ref.get_ref() as LoopbackTransport if ref != null else null
