class_name RoomPeers
extends RefCounted
## Wires one room's RoomSignaling, WebRtcTransport and LobbyModel together (Phase 6 online).
## Host: a hello takes a slot (or is refused when full) and gets an offer; picks, connections,
## failures and rtt update the model, which is re-broadcast on change and every STATE_REPEAT_MS.
## Client: adopts its assigned id, answers the host's offer and mirrors the host's lobby state.

signal changed
## stage: "ice" | "timeout" (WebRtcTransport.link_failed).
signal connect_failed(peer_id: int, stage: String)
signal host_left
signal rejected(reason: String)
signal start_received(data: Dictionary)

const STATE_REPEAT_MS := 2_000
const REJECT_FULL := "full"
const REJECT_STARTED := "started"
const REJECT_ERROR := "error"

var model := LobbyModel.new()
var signaling: RoomSignaling
var transport: WebRtcTransport
var is_host: bool
## Set once the match starts: no new players, lost links are the netcode's business.
var locked: bool = false

var _next_state_ms: int = 0


func _init(p_signaling: RoomSignaling, p_transport: WebRtcTransport) -> void:
	signaling = p_signaling
	transport = p_transport
	is_host = signaling.is_host
	signaling.description.connect(transport.handle_description)
	signaling.candidate.connect(transport.handle_candidate)
	signaling.peer_left.connect(_on_peer_left)
	transport.description_ready.connect(signaling.send_description)
	transport.candidate_ready.connect(signaling.send_candidate)
	transport.peer_connected.connect(_on_connected)
	transport.peer_disconnected.connect(_on_link_lost)
	transport.link_failed.connect(_on_link_failed)
	if is_host:
		signaling.peer_hello.connect(_on_hello)
		signaling.pick.connect(_on_pick)
		model.add_human(LobbyModel.HOST_ID)
	else:
		signaling.assigned.connect(transport.set_local_id)
		signaling.lobby_state.connect(_on_lobby_state)
		signaling.rejected.connect(func(reason: String) -> void: rejected.emit(reason))
		signaling.start.connect(func(data: Dictionary) -> void: start_received.emit(data))


func local_id() -> int:
	return signaling.local_id


## This side's character and ready flag (the host applies it, a client asks the host).
func pick(character: String, ready: bool) -> void:
	if local_id() == 0:
		return  # not seated yet
	model.set_pick(local_id(), character, ready)
	if is_host:
		share()
	else:
		signaling.send_pick({"character": character, "ready": ready})
	changed.emit()


## Host: broadcasts the lobby state now (after any local change: rule, arena, bots).
func share() -> void:
	if not is_host:
		return
	signaling.send_lobby(model.to_state())
	_next_state_ms = 0


## Host: refreshes rtt and repeats the state now and then (late joiners, lost broadcasts).
func tick(now_ms: int) -> void:
	if not is_host or now_ms < _next_state_ms:
		return
	_next_state_ms = now_ms + STATE_REPEAT_MS
	for peer: int in transport.peers():
		model.set_conn(peer, LobbyModel.CONN_CONNECTED, roundi(transport.rtt_ms(peer)))
	signaling.send_lobby(model.to_state())
	changed.emit()


func _on_hello(peer_id: int, info: Dictionary) -> void:
	if locked:
		signaling.reject(peer_id, REJECT_STARTED)
		return
	if model.add_human(peer_id) < 0:
		signaling.reject(peer_id, REJECT_FULL)
		return
	model.set_name(peer_id, info.get("name", ""))
	transport.open_link(peer_id, true)
	share()
	changed.emit()


func _on_pick(peer_id: int, choice: Dictionary) -> void:
	model.set_pick(peer_id, String(choice.get("character", "")), bool(choice.get("ready", false)))
	share()
	changed.emit()


func _on_peer_left(peer_id: int) -> void:
	if not is_host:
		if peer_id == LobbyModel.HOST_ID:
			host_left.emit()
		return
	model.remove_peer(peer_id)
	transport.drop_peer(peer_id)
	signaling.drop(peer_id)
	share()
	changed.emit()


func _on_connected(peer_id: int) -> void:
	if is_host:
		model.set_conn(peer_id, LobbyModel.CONN_CONNECTED, roundi(transport.rtt_ms(peer_id)))
		share()
	changed.emit()


## A link that never opened: tracked, then handled like a lost link.
func _on_link_failed(peer_id: int, stage: String) -> void:
	connect_failed.emit(peer_id, stage)
	_on_link_lost(peer_id)


## Host: the seat is freed and the client told (it may still hear the channel). Client: the host
## is gone. Ignored once the match runs (the netcode handles disconnects).
func _on_link_lost(peer_id: int) -> void:
	if locked:
		return
	if not is_host:
		if peer_id == LobbyModel.HOST_ID:
			host_left.emit()
		return
	signaling.reject(peer_id, REJECT_ERROR)
	model.remove_peer(peer_id)
	transport.drop_peer(peer_id)
	share()
	changed.emit()


func _on_lobby_state(state: Dictionary) -> void:
	model.from_state(state)
	changed.emit()
