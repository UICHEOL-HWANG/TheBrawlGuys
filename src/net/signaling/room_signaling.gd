class_name RoomSignaling
extends RefCounted
## Room signaling state machine over a broadcast channel (Phase 6 online, star topology: the host
## is peer 1). Every payload carries from / to peer ids (to 0 = everyone) and the sender's session
## uuid. A client sends hello (repeated until answered); the host gives it the next peer id and
## sends the WebRTC offer with to_session, which tells the client its id. answer / ice follow;
## leave ends a peer. Lobby events ride along: lobby (host state), pick (client choice), start.
## `send` is (event: String, payload: Dictionary) -> bool, normally RealtimeChannel.broadcast.

signal peer_hello(peer_id: int, info: Dictionary)
## Client: the host gave this side its peer id.
signal assigned(peer_id: int)
signal rejected(reason: String)
signal description(peer_id: int, type: String, sdp: String)
signal candidate(peer_id: int, mid: String, index: int, name: String)
signal peer_left(peer_id: int)
signal lobby_state(state: Dictionary)
signal pick(peer_id: int, choice: Dictionary)
signal start(data: Dictionary)

const HOST_ID := 1
const EV_HELLO := "hello"
const EV_REJECT := "reject"
const EV_OFFER := "offer"
const EV_ANSWER := "answer"
const EV_ICE := "ice"
const EV_LEAVE := "leave"
const EV_LOBBY := "lobby"
const EV_PICK := "pick"
const EV_START := "start"
const HELLO_REPEAT_MS := 2_000
## hello names are untrusted: only this many characters reach the lobby.
const NAME_MAX := 24

var is_host: bool
var session: String
var local_id: int
var send: Callable = func(_event: String, _payload: Dictionary) -> bool: return false

var _sessions: Dictionary = {}  # host: session -> peer id
var _next_id: int = HOST_ID + 1
var _next_hello_ms: int = 0
var _info: Dictionary = {}
var _saying_hello: bool = false
## Client: the host's session, pinned by the first offer; everything else must come from it.
var _host_session: String = ""


func _init(p_is_host: bool, p_session: String) -> void:
	is_host = p_is_host
	session = p_session
	local_id = HOST_ID if p_is_host else 0


## Client: say hello now and every HELLO_REPEAT_MS until assigned (info: name, user_id).
func hello(info: Dictionary, now_ms: int) -> void:
	_info = info
	_saying_hello = true
	_next_hello_ms = now_ms
	tick(now_ms)


func tick(now_ms: int) -> void:
	if is_host or local_id != 0 or not _saying_hello or now_ms < _next_hello_ms:
		return
	_next_hello_ms = now_ms + HELLO_REPEAT_MS
	_send(EV_HELLO, HOST_ID, _info)


func send_description(peer_id: int, type: String, sdp: String) -> void:
	var extra := {"type": type, "sdp": sdp}
	if is_host:
		extra["to_session"] = _session_of(peer_id)
	_send(EV_OFFER if type == "offer" else EV_ANSWER, peer_id, extra)


func send_candidate(peer_id: int, mid: String, index: int, name: String) -> void:
	_send(EV_ICE, peer_id, {"mid": mid, "index": index, "name": name})


## Host: refuses a peer (room full or already playing) and forgets it.
func reject(peer_id: int, reason: String) -> void:
	_send(EV_REJECT, 0, {"to_session": _session_of(peer_id), "reason": reason})
	drop(peer_id)


func send_lobby(state: Dictionary) -> void:
	_send(EV_LOBBY, 0, {"state": state})


func send_pick(choice: Dictionary) -> void:
	_send(EV_PICK, HOST_ID, {"choice": choice})


func send_start(data: Dictionary) -> void:
	_send(EV_START, 0, {"data": data})


func leave() -> void:
	_send(EV_LEAVE, 0, {})


## Host: forgets a peer's session (a hello from it later counts as a new peer).
func drop(peer_id: int) -> void:
	var sid := _session_of(peer_id)
	if not sid.is_empty():
		_sessions.erase(sid)


## Routes one broadcast (connect RealtimeChannel.message here).
func handle(event: String, p: Dictionary) -> void:
	var from := int(p.get("from", 0))
	var to := int(p.get("to", 0))
	if String(p.get("session", "")) == session:
		return  # our own echo
	if event == EV_HELLO:
		if is_host:
			_on_hello(p)
		return
	if event == EV_REJECT or (event == EV_OFFER and not is_host):
		_on_addressed_by_session(event, p)
		return
	if local_id == 0 or (to != 0 and to != local_id):
		return
	var sender := _session_of(from) if is_host else _host_session
	if from < HOST_ID or (not is_host and from != HOST_ID) or sender != String(p.get("session", "")):
		return  # unknown or spoofed sender (a client listens to the pinned host only)
	_route(event, from, p)


func _route(event: String, from: int, p: Dictionary) -> void:
	match event:
		EV_ANSWER:
			description.emit(from, "answer", String(p.get("sdp", "")))
		EV_ICE:
			candidate.emit(from, String(p.get("mid", "")), int(p.get("index", 0)), String(p.get("name", "")))
		EV_LEAVE:
			drop(from)
			peer_left.emit(from)
		EV_LOBBY:
			if from == HOST_ID and p.get("state") is Dictionary:
				lobby_state.emit(p["state"])
		EV_PICK:
			if is_host and p.get("choice") is Dictionary:
				pick.emit(from, p["choice"])
		EV_START:
			if from == HOST_ID and p.get("data") is Dictionary:
				start.emit(p["data"])


func _on_hello(p: Dictionary) -> void:
	var sid := String(p.get("session", ""))
	if sid.is_empty() or _sessions.has(sid):
		return  # a repeated hello
	_sessions[sid] = _next_id
	_next_id += 1
	var info := {"session": sid, "name": String(p.get("name", "")).left(NAME_MAX)}
	peer_hello.emit(int(_sessions[sid]), info)


## Client: messages addressed by session (reject, offers). The first offer from peer 1 pins the
## host's session and gives this side its id; later ones must come from that session.
func _on_addressed_by_session(event: String, p: Dictionary) -> void:
	var sender := String(p.get("session", ""))
	if String(p.get("to_session", "")) != session or int(p.get("from", 0)) != HOST_ID:
		return
	if not _host_session.is_empty() and sender != _host_session:
		return  # not the host this side already talks to
	if event == EV_REJECT:
		rejected.emit(String(p.get("reason", "")))
		return
	if local_id == 0:
		var id := int(p.get("to", 0))
		if id <= HOST_ID or sender.is_empty():
			return
		_host_session = sender
		local_id = id
		assigned.emit(local_id)
	description.emit(HOST_ID, "offer", String(p.get("sdp", "")))


func _send(event: String, to: int, extra: Dictionary) -> void:
	var payload := {"from": local_id, "to": to, "session": session}
	payload.merge(extra)
	send.call(event, payload)


func _session_of(peer_id: int) -> String:
	for sid: String in _sessions:
		if int(_sessions[sid]) == peer_id:
			return sid
	return ""
