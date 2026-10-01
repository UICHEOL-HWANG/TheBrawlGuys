class_name HostSession
extends RefCounted
## The authoritative side of an online match (peer 1, PRD-NET-01 / online design). Whoever ticks the
## World (NetMatch, tests) asks inputs() for one InputFrame per slot — local players as given,
## bots from their BotController, remote players from their queued client inputs (held last input
## when one is late) — then reports the tick with after_tick(): snapshots go out every
## 60 / net_snapshot_hz ticks with each client's acked input seq, sim events follow reliably, END
## once the match is over. A dropped player's slot plays neutral for net_disconnect_grace seconds
## (a reconnect may take it back, NetRoster), then a bot takes over; BYE hands it to a bot at once.

signal client_joined(peer_id: int, slot: int)
signal slot_botted(slot: int, reason: String)

const REASON_TIMEOUT := "timeout"
const REASON_LEFT := "left"
const RTT_SAMPLE_MS := 1000

var setup: MatchSetup
var stats := NetStats.new(true)
var roster: NetRoster
var _t: NetTransport
var _config: GameConfig
var _clock: Callable
## slot -> BotController (bot slots and remote slots a bot took over)
var _bots: Dictionary = {}
var _last_codes := PackedInt32Array()
var _events: Array = []
var _since_snapshot: int = 0
var _tick: int = 0
var _running: bool = false
var _end_sent: bool = false
var _next_rtt_ms: int = 0


## peer_slots: peer id -> slot the lobby gave that player (optional).
func _init(transport: NetTransport, p_setup: MatchSetup, config: GameConfig,
		clock_ms: Callable = Time.get_ticks_msec, peer_slots: Dictionary = {}) -> void:
	_t = transport
	setup = p_setup
	_config = config
	_clock = clock_ms
	roster = NetRoster.new(setup, config.net_input_buffer_max, peer_slots)
	for slot: int in setup.bot_slots():
		_bots[slot] = BotController.new(slot, config)
	for i: int in setup.player_count():
		_last_codes.append(InputCodec.NEUTRAL)
	_t.peer_disconnected.connect(_on_peer_left.bind(REASON_TIMEOUT))  # no lambda: no reference cycle


## The match starts: welcomed clients get START; slots nobody joined start their grace period.
func start(world: World) -> void:
	_running = true
	_tick = world.tick_count
	for r: NetRemoteSlot in roster.connected():
		_t.send(r.peer_id, NetTransport.CHANNEL_RELIABLE, NetProtocol.start(_tick))
	roster.mark_unjoined(_now())


func poll() -> void:
	for m: Dictionary in _t.poll():
		var msg := NetProtocol.decode(m["bytes"])
		if not msg.is_empty():
			_handle(int(m["from"]), msg)
	if _running:
		var grace_ms := int(_config.net_disconnect_grace * 1000.0)
		for r: NetRemoteSlot in roster.expired(_now(), grace_ms):
			_to_bot(r, REASON_TIMEOUT)
	_sample_rtt()


## One input per slot in slot order. locals: slot -> InputFrame for this machine's players.
func inputs(view: Dictionary, locals: Dictionary) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for s: Dictionary in setup.slots:
		var slot := int(s["slot"])
		if _bots.has(slot):
			out.append((_bots[slot] as BotController).sample(view))
		elif roster.has(slot):
			var r := roster.at(slot)
			out.append(InputCodec.unpack(r.next_code()) if r.connected else InputFrame.neutral())
		else:
			out.append(locals.get(slot, InputFrame.neutral()))
	return out


## After World.tick(inputs): events are that tick's sim events.
func after_tick(world: World, inputs: Array[InputFrame], events: Array) -> void:
	for i: int in mini(inputs.size(), _last_codes.size()):
		_last_codes[i] = InputCodec.pack(inputs[i])
	_events.append_array(events)
	_tick = world.tick_count
	_since_snapshot += 1
	var ending := world.match_over and not _end_sent
	if _since_snapshot >= snapshot_interval(_config) or ending:
		_send_state(world)
	if ending:
		_end_sent = true
		_broadcast(NetTransport.CHANNEL_RELIABLE, NetProtocol.end(world.winner_id))


## Host ticks between snapshots.
static func snapshot_interval(config: GameConfig) -> int:
	return maxi(1, roundi(float(SimTime.TICK_RATE) / maxf(1.0, config.net_snapshot_hz)))


func is_bot(slot: int) -> bool:
	return _bots.has(slot)


## Leaving: every client hears BYE (the match ends for them).
func close() -> void:
	_broadcast(NetTransport.CHANNEL_RELIABLE, NetProtocol.bye())


func _handle(peer: int, msg: Dictionary) -> void:
	match int(msg["type"]):
		NetProtocol.Type.HELLO:
			_welcome(peer)
		NetProtocol.Type.INPUTS:
			var r := roster.of_peer(peer)
			if r != null:
				r.receive(int(msg["seq"]), msg["codes"])
		NetProtocol.Type.PING:
			_t.send(peer, NetTransport.CHANNEL_FAST, NetProtocol.pong(int(msg["ms"])))
		NetProtocol.Type.BYE:
			_on_peer_left(peer, REASON_LEFT)


func _welcome(peer: int) -> void:
	var r := roster.claim(peer)
	if r == null:
		_t.send(peer, NetTransport.CHANNEL_RELIABLE, NetProtocol.bye())  # room full
		return
	_t.send(peer, NetTransport.CHANNEL_RELIABLE, NetProtocol.welcome(r.slot, SetupCodec.to_dict(setup)))
	if _running:
		_t.send(peer, NetTransport.CHANNEL_RELIABLE, NetProtocol.start(_tick))
	client_joined.emit(peer, r.slot)


func _on_peer_left(peer: int, reason: String) -> void:
	var r := roster.of_peer(peer)
	if r == null:
		return
	r.drop(_now())
	stats.disconnects += 1
	if reason == REASON_LEFT:
		_to_bot(r, reason)


func _to_bot(r: NetRemoteSlot, reason: String) -> void:
	r.is_bot = true
	_bots[r.slot] = BotController.new(r.slot, _config)
	slot_botted.emit(r.slot, reason)


func _send_state(world: World) -> void:
	_since_snapshot = 0
	if not _events.is_empty():
		_broadcast(NetTransport.CHANNEL_RELIABLE, NetProtocol.events(_tick, _events))
		_events = []
	var acks := roster.acks(_last_codes.size())
	_broadcast(NetTransport.CHANNEL_FAST, NetProtocol.snapshot(_tick, acks, _last_codes, world.snapshot()))


## To every connected client (never to peers that have not been welcomed).
func _broadcast(channel: int, bytes: PackedByteArray) -> void:
	for r: NetRemoteSlot in roster.connected():
		_t.send(r.peer_id, channel, bytes)


func _sample_rtt() -> void:
	if _now() < _next_rtt_ms:
		return
	_next_rtt_ms = _now() + RTT_SAMPLE_MS
	for r: NetRemoteSlot in roster.connected():
		stats.add_rtt(_t.rtt_ms(r.peer_id))


func _now() -> int:
	return int(_clock.call())
