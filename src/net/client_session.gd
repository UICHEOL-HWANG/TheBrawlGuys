class_name ClientSession
extends RefCounted
## A joining player's side of an online match (online design). Says HELLO, gets its slot and the
## MatchSetup in WELCOME (setup is then this client's view of it: own slot local, other humans
## remote), and plays once START arrives. Whoever ticks the client's World copy (NetMatch, tests)
## calls step() with the own input each tick (sent to the host with the last
## net_input_redundancy inputs, and predicted at once, NetPrediction) and view() for the state to
## draw (NetInterpolation). poll() applies snapshots, sim events, END, PONG and the host leaving.

signal welcomed(slot: int)
signal started
signal ended(winner: int)
signal host_left

const HOST_ID := 1
const PING_MS := 1000

var slot: int = -1
var setup: MatchSetup = null
var running: bool = false
var winner: int = Rules.ONGOING
var gone: bool = false
var stats := NetStats.new(false)
var prediction: NetPrediction = null
var interpolation: NetInterpolation = null
var _t: NetTransport
var _config: GameConfig
var _clock: Callable
var _events: Array = []
var _last_snapshot: int = -1
var _next_ping_ms: int = 0


func _init(transport: NetTransport, config: GameConfig, clock_ms: Callable = Time.get_ticks_msec) -> void:
	_t = transport
	_config = config
	_clock = clock_ms
	# Method callables, not lambdas: a lambda would hold this session and the transport holds it back.
	_t.peer_disconnected.connect(_on_peer_disconnected)
	_t.peer_connected.connect(_on_peer_connected)
	_hello()


## world: this client's World copy (null until the match scene built it; snapshots wait).
func poll(world: World) -> void:
	for m: Dictionary in _t.poll():
		if int(m["from"]) != HOST_ID:
			continue
		var msg := NetProtocol.decode(m["bytes"])
		if not msg.is_empty():
			_handle(msg, world)
	if running and _now() >= _next_ping_ms:
		_next_ping_ms = _now() + PING_MS
		_t.send(HOST_ID, NetTransport.CHANNEL_FAST, NetProtocol.ping(_now()))


## One client tick: send and predict the own input.
func step(world: World, own: InputFrame) -> void:
	var frames := prediction.next(own)
	_t.send(HOST_ID, NetTransport.CHANNEL_FAST,
			NetProtocol.inputs(prediction.seq(), prediction.recent_codes(_config.net_input_redundancy)))
	world.tick(frames)
	interpolation.advance()


## The state to draw this tick; carries (and clears) the host's sim events received since last time.
func view(world: World) -> Dictionary:
	var events := _events
	_events = []
	return interpolation.compose(world.state_view(), slot, events)


## Leaving on purpose: the host gives the slot to a bot at once.
func leave() -> void:
	if not gone:
		_t.send(HOST_ID, NetTransport.CHANNEL_RELIABLE, NetProtocol.bye())


func _handle(msg: Dictionary, world: World) -> void:
	match int(msg["type"]):
		NetProtocol.Type.WELCOME:
			_on_welcome(msg)
		NetProtocol.Type.START:
			if setup != null and not running:
				running = true
				started.emit()
		NetProtocol.Type.SNAPSHOT:
			_on_snapshot(msg, world)
		NetProtocol.Type.EVENTS:
			_events.append_array(msg["events"])
		NetProtocol.Type.END:
			winner = int(msg["winner"])
			ended.emit(winner)
		NetProtocol.Type.PONG:
			stats.add_rtt(float(_now() - int(msg["ms"])))
		NetProtocol.Type.BYE:
			_lose()


func _on_welcome(msg: Dictionary) -> void:
	if setup != null:
		return
	var s := SetupCodec.from_dict(msg["setup"])
	var own := int(msg["slot"])
	if s == null or own >= s.player_count():
		push_warning("ClientSession: invalid WELCOME ignored")
		return
	slot = own
	setup = SetupCodec.for_client(s, own)
	prediction = NetPrediction.new(slot, setup.player_count(), _config)
	interpolation = NetInterpolation.new(NetInterpolation.delay_ticks(_config))
	welcomed.emit(slot)


func _on_snapshot(msg: Dictionary, world: World) -> void:
	var tick := int(msg["tick"])
	if world == null or prediction == null or tick <= _last_snapshot:
		return
	var view := prediction.reconcile(world, msg)
	if view.is_empty():
		return
	_last_snapshot = tick
	interpolation.push(tick, view)
	stats.corrections = prediction.corrections


func _on_peer_disconnected(peer: int) -> void:
	if peer == HOST_ID:
		_lose()


func _on_peer_connected(peer: int) -> void:
	if peer == HOST_ID and setup == null:
		_hello()


func _hello() -> void:
	_t.send(HOST_ID, NetTransport.CHANNEL_RELIABLE, NetProtocol.hello())


func _lose() -> void:
	if gone:
		return
	gone = true
	stats.disconnects += 1
	host_left.emit()


func _now() -> int:
	return int(_clock.call())
