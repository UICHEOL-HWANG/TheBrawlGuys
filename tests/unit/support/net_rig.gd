extends RefCounted
## Test helper: an online match over a LoopbackHub without scenes, ticked the way NetMatch ticks it.
## Slot 0 is the host's local player, slots 1..clients are remote players (one ClientSession and
## World copy each), any further slot is a bot. Each tick(): clients poll + step, host polls,
## gathers inputs, ticks and reports; then the hub clock moves one tick. The host's applied inputs,
## state hash and fighter positions are kept per host tick.

const TICK_MS := 1000.0 / 60.0
const SEED := 7

var hub: LoopbackHub
var config: GameConfig
var setup: MatchSetup
var host: HostSession
var host_t: LoopbackTransport
var host_world: World
var clients: Array[ClientSession] = []
var client_ts: Array[LoopbackTransport] = []
var client_worlds: Array[World] = []
## host tick -> state hash / Array of fighter positions after that tick
var host_hashes: Dictionary = {}
var host_positions: Dictionary = {}
## Inputs the host applied, one Array[InputFrame] per tick.
var applied: Array = []
## Client clock speed relative to the host (1.01 = 1 % fast) and whether NetClockSync steers it;
## with both at their defaults every client steps exactly once per host tick.
var client_rates: Array[float] = []
var use_sync: bool = false
var _acc: Array[float] = []


func _init(p_config: GameConfig, players: int, remote_count: int, latency_ms: float = 0.0,
		jitter_ms: float = 0.0, loss_pct: float = 0.0) -> void:
	config = p_config
	setup = MatchSetup.vs_bots(players, SEED)
	setup.mode = MatchSetup.MODE_ONLINE
	for i: int in range(1, remote_count + 1):
		setup.slots[i] = MatchSetup.slot_entry(i, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	hub = LoopbackHub.new(SEED)
	hub.set_conditions(latency_ms, jitter_ms, loss_pct)
	host_t = hub.host()
	host = HostSession.new(host_t, setup, config, now_ms)
	host_world = setup.build_world(config)
	for i: int in remote_count:
		var t := hub.join()
		client_ts.append(t)
		clients.append(ClientSession.new(t, config, now_ms))
		client_worlds.append(null)
		client_rates.append(1.0)
		_acc.append(0.0)


func now_ms() -> int:
	return int(hub.now_ms())


## Lets HELLO / WELCOME travel, starts the host, lets START travel (advancing the clock as needed),
## then builds each client's World copy from the setup it was sent.
func connect_all(max_ms: float = 2000.0) -> void:
	_until(func() -> bool: return clients.all(func(c: ClientSession) -> bool: return c.setup != null), max_ms)
	host.start(host_world)
	_until(func() -> bool: return clients.all(func(c: ClientSession) -> bool: return c.running), max_ms)
	for i: int in clients.size():
		client_worlds[i] = clients[i].setup.build_world(config)


## One frame. client_inputs[i] is client i's own input (missing = neutral).
func tick(host_input: InputFrame = InputFrame.neutral(), client_inputs: Array = []) -> void:
	_poll_clients()
	for i: int in clients.size():
		var c := clients[i]
		if c.running and not c.gone:
			var own: InputFrame = client_inputs[i] if i < client_inputs.size() else InputFrame.neutral()
			for s: int in _client_steps(i):
				c.step(client_worlds[i], own)
	host.poll()
	var inputs := host.inputs(host_world.state_view(), {0: host_input})
	host_world.tick(inputs)
	host.after_tick(host_world, inputs, host_world.state_view()["events"])
	applied.append(inputs)
	host_hashes[host_world.tick_count] = host_world.state_hash()
	var positions: Array = []
	for f: Fighter in host_world.fighters:
		positions.append(f.pos)
	host_positions[host_world.tick_count] = positions
	hub.advance(TICK_MS)


## A fresh World fed exactly the host's applied inputs.
func replay_reference() -> World:
	var w := setup.build_world(config)
	for inputs: Array in applied:
		var frame: Array[InputFrame] = []
		frame.assign(inputs)
		w.tick(frame)
	return w


## Deterministic busy input for slot at tick (circles, periodic presses and guards).
static func scripted(tick: int, slot: int) -> InputFrame:
	var a := tick * 0.05 + slot * 2.0
	return InputFrame.make(cos(a), sin(a), tick % 40 == slot * 3, tick % 25 == slot * 5,
			tick % 90 == 45, (tick / 60) % 5 == 4, false)


## Client ticks this host tick: 1, or what its (drifting, maybe synced) clock accumulated.
func _client_steps(i: int) -> int:
	if not use_sync and client_rates[i] == 1.0:
		return 1
	_acc[i] += client_rates[i] * (clients[i].tick_rate_scale() if use_sync else 1.0)
	var steps := int(_acc[i])
	_acc[i] -= steps
	return steps


func poll_clients() -> void:
	_poll_clients()


func _poll_clients() -> void:
	for i: int in clients.size():
		clients[i].poll(client_worlds[i])


func _until(done: Callable, max_ms: float) -> void:
	var waited := 0.0
	while waited <= max_ms:
		host.poll()
		_poll_clients()
		if done.call():
			return
		hub.advance(TICK_MS)
		waited += TICK_MS
