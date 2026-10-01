class_name OnlineRoom
extends Node
## One online room's lifecycle (Phase 6, PRD-NET-03): create (rooms row + Realtime channel) or
## join (look the code up, then the channel), the lobby (RoomPeers), start (OnlineStart.begin on
## every device) and leave (closes the row when hosting). Polls the channel, signaling and
## transport in _process. Tracks room_created / room_joined / room_left / peer_connect_failed.

signal opened(code: String)
signal changed
## The room is over for this device (reason: back | host_left | full | not_found | started | error).
signal left(reason: String, message: String)
signal notice(text: String)
signal match_ready(scene: Node)

## PLAYING: the scene from OnlineStart.begin owns the transport; the lobby stays quiet.
enum Phase { IDLE, PREPARING, CONNECTING, LOBBY, PLAYING, CLOSED }

const ASSIGN_TIMEOUT_MS := 12_000
const STAGE_SIGNALING := "signaling"
const MSG := {"error": "연결하지 못했어요. 잠시 뒤 다시 해 주세요", "not_found": "그 코드의 방이 없어요",
	"full": "방이 가득 찼어요", "started": "이미 시작한 방이에요", "host_left": "방장이 나갔어요", "create": "방을 만들지 못했어요"}

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec
var new_seed: Callable = MatchSeed.fresh
## (is_host: bool) -> RealtimeChannel; tests pass a fake-socket channel.
var channel_factory: Callable = func(_is_host: bool) -> RealtimeChannel: return RealtimeChannel.new()
var peer_factory: Callable = WebRtcSupport.new_peer
var rooms: RoomsApi
var socket_url: String = ""
var access_token: String = ""
var ice: Dictionary = {}

var code: String = ""
var is_host: bool = false
var peers: RoomPeers = null
var _channel: RealtimeChannel = null
var _phase: Phase = Phase.IDLE
var _opened_ms: int = 0
var _room_count: int = 1


func phase() -> Phase:
	return _phase


func create(rule: String, arena: String) -> void:
	is_host = true
	_phase = Phase.PREPARING
	rooms.create(rule, arena, func(ok: bool, room: String, attempts: int, _status: int) -> void:
		if _phase == Phase.CLOSED:  # left while the row was being made
			if ok:
				rooms.close(room)
			return
		if not ok:
			_end("error", MSG["create"])
			return
		code = room
		track.call("room_created", {"attempts": attempts, "rule": rule, "arena": arena})
		_open_channel(rule, arena))


func join(room: String) -> void:
	is_host = false
	code = room
	_phase = Phase.PREPARING
	rooms.lookup(room, func(ok: bool, row: Dictionary, status: int) -> void:
		var refusal := RoomsApi.join_refusal(ok, row, status, LobbyModel.MAX_SLOTS)
		if _phase != Phase.CLOSED and refusal.is_empty():
			_open_channel("", "")
		elif _phase != Phase.CLOSED:
			_end(refusal, ""))


func _process(_delta: float) -> void:
	if _channel == null or _phase == Phase.CLOSED:
		return
	var now := int(clock_ms.call())
	_channel.poll(now)
	if peers == null or _phase == Phase.CLOSED or _phase == Phase.PLAYING:
		return  # in a match NetMatch polls the transport; the lobby stays quiet
	peers.signaling.tick(now)
	peers.transport.service()
	peers.tick(now)
	if not is_host and _phase == Phase.LOBBY and peers.local_id() == 0 and now - _opened_ms > ASSIGN_TIMEOUT_MS:
		_fail_connect(STAGE_SIGNALING)


## Host only, when the lobby allows it: every device calls OnlineStart.begin.
func start_match() -> void:
	if not is_host or _phase != Phase.LOBBY or not peers.model.can_start():
		return
	var data := {"seed": int(new_seed.call()), "state": peers.model.to_state()}
	peers.locked = true
	peers.signaling.send_start(data)
	rooms.update(code, {"status": RoomsApi.STATUS_PLAYING})
	_begin(data)


func leave(reason: String = "back") -> void:
	if _phase == Phase.CLOSED:
		return
	var was := _phase
	_phase = Phase.CLOSED  # first: closing the transport reports lost links back here
	if peers != null:
		peers.signaling.leave()
		peers.transport.close()
	if is_host and not code.is_empty():
		rooms.close(code)
	if _channel != null:
		_channel.close()
	if was == Phase.LOBBY:
		track.call("room_left", {"reason": reason, "is_host": is_host,
			"dwell_ms": int(clock_ms.call()) - _opened_ms})


## Host: rule / arena / bot changes go to everyone and to the rooms row.
func host_changed() -> void:
	if is_host and peers != null:
		peers.share()
		rooms.update(code, {"rule": peers.model.rule, "arena": peers.model.arena})
		changed.emit()


func _open_channel(rule: String, arena: String) -> void:
	_phase = Phase.CONNECTING
	var signaling := RoomSignaling.new(is_host, Uuid.v4())
	var transport := WebRtcTransport.new(RoomSignaling.HOST_ID if is_host else 0, ice)
	transport.peer_factory = peer_factory
	transport.clock_ms = clock_ms
	peers = RoomPeers.new(signaling, transport)
	if is_host:
		peers.model.rule = rule
		peers.model.arena = arena
	_channel = channel_factory.call(is_host) as RealtimeChannel
	signaling.send = _channel.broadcast
	_channel.message.connect(signaling.handle)
	_channel.joined.connect(_on_joined)
	_channel.failed.connect(func(_reason: String) -> void: _fail_connect(STAGE_SIGNALING))
	_connect_peers()
	_channel.open(socket_url, PhoenixMessage.topic_for("room:" + code), access_token, int(clock_ms.call()))


func _connect_peers() -> void:
	peers.changed.connect(_on_peers_changed)
	peers.connect_failed.connect(func(peer_id: int, stage: String) -> void:
		track.call("peer_connect_failed", {"stage": stage, "is_host": is_host, "peer_id": peer_id}))
	peers.host_left.connect(func() -> void: _end("host_left", ""))
	peers.rejected.connect(func(reason: String) -> void: _end(reason if MSG.has(reason) else "error", ""))
	peers.start_received.connect(_begin)


func _on_joined() -> void:
	_phase = Phase.LOBBY
	_opened_ms = int(clock_ms.call())
	if is_host:
		peers.share()
	else:
		peers.signaling.hello({"name": ""}, _opened_ms)
	track.call("room_joined", {"is_host": is_host, "player_count": peers.model.human_count()})
	opened.emit(code)


func _on_peers_changed() -> void:
	var count := peers.model.human_count()
	if is_host and count != _room_count:
		_room_count = count
		rooms.update(code, {"player_count": count})
	changed.emit()


func _begin(data: Dictionary) -> void:
	if data.get("state") is Dictionary:
		peers.model.from_state(data["state"])
	var setup := peers.model.build_setup(peers.local_id(), int(data.get("seed", 1)))
	peers.locked = true
	var scene := OnlineStart.begin(peers.transport, is_host, setup, peers.model.slot_map())
	if scene == null:  # back to the lobby
		peers.locked = false
		if is_host:
			rooms.update(code, {"status": RoomsApi.STATUS_WAITING})
		notice.emit(OnlineStart.START_FAILED_TEXT)
		return
	_phase = Phase.PLAYING
	match_ready.emit(scene)


func _fail_connect(stage: String) -> void:
	track.call("peer_connect_failed", {"stage": stage, "is_host": is_host, "peer_id": RoomSignaling.HOST_ID})
	_end("error", "")


## Lobby exits only; during a match the netcode reports disconnects itself.
func _end(reason: String, message: String) -> void:
	var was := _phase
	if was == Phase.PLAYING:
		return
	leave(reason)
	if was != Phase.CLOSED:
		left.emit(reason, message if not message.is_empty() else String(MSG.get(reason, MSG["error"])))
