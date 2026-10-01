class_name NetMatch
extends "res://src/main/main.gd"
## Online match scene (Phase 6, online design): main.gd's match loop with inputs and state from the
## network, so stage, HUD, feel, sound and tracking work as in a local match. Host: HostSession
## supplies remote players' inputs (and bots), and snapshots / events go out after every tick.
## Client: the World here is a prediction copy; ClientSession predicts the own fighter and draws the
## others ~100 ms behind. Configure before add_child:
##   host_match(transport, setup, peer_slots) — setup: host's slot "local", other humans "remote",
##       bots "bot"; peer_slots (optional) peer id -> slot from the lobby
##   join_match(transport) — the setup arrives in WELCOME; nothing runs until START
## The host boots once every lobby player said HELLO (or after join_wait_ms, net_join_wait, or
## when no peer is left), so nobody starts a few hundred ms behind. A client that got WELCOME but
## no START within start_timeout_ms reports connection_lost(timeout).
## No rematch online: the result offers 메뉴로 (menu_requested). Leaving the tree sends BYE; the
## transport stays the caller's to close. connection_lost(reason) fires when the connection ends:
## ClientSession.LOST_HOST_LEFT, LOST_ROOM_FULL or LOST_TIMEOUT (no WELCOME within 5 s).

signal connection_lost(reason: String)

const ROLE_HOST := "host"
const ROLE_CLIENT := "client"
const LOST_HOST_LEFT := ClientSession.LOST_HOST_LEFT

var _role: String = ""
var _transport: NetTransport = null
var _peer_slots: Dictionary = {}
var _host: HostSession = null
var _client: ClientSession = null
var _booted: bool = false
var _started: bool = false
## Host: ms to wait for the lobby's players before starting without them (-1 = net_join_wait).
var join_wait_ms: int = -1
var _join_deadline_ms: int = 0
## Client: ms from WELCOME to START before giving up (the host waits up to net_join_wait).
var start_timeout_ms: int = 15_000
var _booted_at_ms: int = 0


func host_match(transport: NetTransport, p_setup: MatchSetup, peer_slots: Dictionary = {}) -> void:
	_role = ROLE_HOST
	_transport = transport
	setup = p_setup
	_peer_slots = peer_slots
	menu_available = true


func join_match(transport: NetTransport) -> void:
	_role = ROLE_CLIENT
	_transport = transport
	menu_available = true


func is_host() -> bool:
	return _role == ROLE_HOST


func host_session() -> HostSession:
	return _host


func client_session() -> ClientSession:
	return _client


## Network health for match telemetry (NetStats.props: net_host, rtt_p50/p95, corrections,
## disconnects); {} before the session exists.
func net_stats() -> Dictionary:
	if _host != null:
		return _host.stats.props()
	return _client.stats.props() if _client != null else {}


func _ready() -> void:
	assert(_transport != null, "NetMatch: call host_match() or join_match() before adding it")
	var config := load(CONFIG_PATH) as GameConfig
	if config != null and (OS.is_debug_build() or LaggedTransport.wanted(config)):
		_transport = LaggedTransport.new(_transport, config)
	if _role == ROLE_CLIENT:
		_client = ClientSession.new(_transport, config)
		_client.lost.connect(func(reason: String) -> void: connection_lost.emit(reason))
		return  # boots in _process once WELCOME brought the setup
	_host = HostSession.new(_transport, setup, config, Time.get_ticks_msec, _peer_slots)
	if join_wait_ms < 0:
		join_wait_ms = int(config.net_join_wait * 1000.0)
	_join_deadline_ms = Time.get_ticks_msec() + join_wait_ms
	_boot_host_when_joined()


## Host: WELCOMEs whoever says HELLO, then boots once all are in or the wait ran out.
func _boot_host_when_joined() -> void:
	_host.poll()
	if _host.roster.all_joined() or _transport.peers().is_empty() or Time.get_ticks_msec() >= _join_deadline_ms:
		_boot()


func _boot() -> void:
	_booted = true
	_booted_at_ms = Time.get_ticks_msec()
	if _role == ROLE_CLIENT:
		setup = _client.setup
	super._ready()


## Telemetry shares the host's match id; only the host uploads Supabase rows (authoritative, its
## input log replays), clients send their Amplitude events only.
func _new_tracking() -> MatchTracking:
	var recorder := MatchRecorder.create_default() if _role == ROLE_HOST else MatchRecorder.new(null)
	var tracking := MatchTracking.new(Analytics.track, recorder)
	tracking.match_id = _host.match_id if _host != null else _client.match_id
	tracking.net_props = net_stats
	return tracking


## Online there is one match per scene: restart / ui_accept after the result do nothing.
func _start_match() -> void:
	if _started:
		return
	_started = true
	super._start_match()
	if _host != null:
		_host.start(_world)


## Clients run their clock a little fast or slow (NetClockSync) to stay in step with the host.
func _process(delta: float) -> void:
	if _role == ROLE_CLIENT:
		_client.poll(_world)
		if not _booted:
			if _client.setup != null:
				_boot()
			return
		if not _client.running:
			if not _client.gone and Time.get_ticks_msec() - _booted_at_ms >= start_timeout_ms:
				_client.leave()
				_client.gone = true  # report once
				connection_lost.emit(ClientSession.LOST_TIMEOUT)
			return
		delta *= _client.tick_rate_scale()
	elif _host != null and not _booted:
		_boot_host_when_joined()
		return
	elif _host != null and _started:
		_host.poll()
	super._process(delta)


func _gather_inputs() -> Array[InputFrame]:
	var locals := {}
	for slot: int in _locals.slots():
		locals[slot] = _locals.sample(slot)
	if _role == ROLE_HOST:
		return _host.inputs(_curr_state, locals)
	var out: Array[InputFrame] = []
	for i: int in setup.player_count():
		out.append(locals.get(i, InputFrame.neutral()))
	return out


func _step(inputs: Array[InputFrame]) -> void:
	if _role != ROLE_CLIENT:
		super._step(inputs)
		return
	_client.step(_world, inputs[_client.slot])
	_curr_state = _client.view(_world)


func _after_tick(inputs: Array[InputFrame]) -> void:
	if _host != null:
		_host.after_tick(_world, inputs, _curr_state["events"])


func _exit_tree() -> void:
	if _host != null:
		_host.close()
	if _client != null:
		_client.leave()
	if _transport is LaggedTransport:
		(_transport as LaggedTransport).flush_all()  # the BYE must not wait for a poll that never comes
	super._exit_tree()
