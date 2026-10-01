class_name LaggedTransport
extends NetTransport
## Debug wrapper around a real transport (GameConfig "Net" net_sim_* sliders): every message sent
## and received on this side is held back by the configured latency + jitter, and fast-channel
## messages are dropped at the loss rate, so one machine can play over a "bad" network. Values are
## read live, so the sliders apply mid-match. Delayed outgoing messages leave on the first send()
## or poll() after they are due.

var _inner: NetTransport
var _config: GameConfig
var _clock: Callable
var _out := NetDelayLine.new(1)
var _in := NetDelayLine.new(2)


func _init(inner: NetTransport, config: GameConfig, clock_ms: Callable = Time.get_ticks_msec) -> void:
	_inner = inner
	_config = config
	_clock = clock_ms
	_inner.peer_connected.connect(peer_connected.emit)
	_inner.peer_disconnected.connect(peer_disconnected.emit)


## True when the config asks for any simulated lag or loss.
static func wanted(config: GameConfig) -> bool:
	return config.net_sim_latency_ms > 0.0 or config.net_sim_jitter_ms > 0.0 or config.net_sim_loss_pct > 0.0


func local_id() -> int:
	return _inner.local_id()


func peers() -> PackedInt32Array:
	return _inner.peers()


## Due messages go out at once (with no lag configured, every message is due when sent).
func send(peer_id: int, channel: int, bytes: PackedByteArray) -> void:
	_apply(_out)
	_out.push(_now(), local_id(), peer_id, channel, bytes)
	_flush(_now())


func poll() -> Array[Dictionary]:
	var now := _now()
	_flush(now)
	_apply(_in)
	for m: Dictionary in _inner.poll():
		_in.push(now, int(m["from"]), local_id(), int(m["channel"]), m["bytes"])
	var out: Array[Dictionary] = []
	for m: Dictionary in _in.pop_due(now):
		out.append({"from": int(m["from"]), "channel": int(m["channel"]), "bytes": m["bytes"]})
	return out


func rtt_ms(peer_id: int) -> float:
	var base := _inner.rtt_ms(peer_id)
	return base + 2.0 * _config.net_sim_latency_ms if base >= 0.0 else base


## Sends everything still held back right now (a BYE when the match scene leaves).
func flush_all() -> void:
	_flush(INF)


func close() -> void:
	flush_all()
	_inner.close()


func _flush(now: float) -> void:
	for m: Dictionary in _out.pop_due(now):
		_inner.send(int(m["to"]), int(m["channel"]), m["bytes"])


func _apply(line: NetDelayLine) -> void:
	line.latency_ms = _config.net_sim_latency_ms
	line.jitter_ms = _config.net_sim_jitter_ms
	line.loss_pct = _config.net_sim_loss_pct


func _now() -> float:
	return float(_clock.call())
