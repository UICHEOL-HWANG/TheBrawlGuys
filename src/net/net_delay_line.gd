class_name NetDelayLine
extends RefCounted
## Messages in flight under simulated network conditions (LoopbackHub, LaggedTransport): one-way
## latency plus up to jitter_ms extra, and loss_pct of CHANNEL_FAST dropped. Both channels stay
## ordered per sender -> receiver pair: a reliable message never arrives before an earlier one, a
## fast message overtaken by a later one is dropped (NetTransport contract). Seeded, so a run with
## the same sends and clock is the same run.

const ANY := -1

var latency_ms: float = 0.0
var jitter_ms: float = 0.0
var loss_pct: float = 0.0
var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []
var _seq: int = 0
## "from>to" -> arrival time of the newest reliable message.
var _reliable_at: Dictionary = {}
## "from>to" -> send sequence of the newest delivered fast message.
var _fast_seq: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	_rng.seed = p_seed


func push(now_ms: float, from: int, to: int, channel: int, bytes: PackedByteArray) -> void:
	if channel == NetTransport.CHANNEL_FAST and loss_pct > 0.0 and _rng.randf() * 100.0 < loss_pct:
		return
	var at := now_ms + latency_ms + (_rng.randf() * jitter_ms if jitter_ms > 0.0 else 0.0)
	var key := _key(from, to)
	if channel == NetTransport.CHANNEL_RELIABLE:
		at = maxf(at, float(_reliable_at.get(key, 0.0)))
		_reliable_at[key] = at
	_seq += 1
	_queue.append({"at": at, "seq": _seq, "from": from, "to": to, "channel": channel, "bytes": bytes})


## Messages for `to` (ANY = every receiver) due by now_ms, in arrival order:
## [{"from", "to", "channel", "bytes"}].
func pop_due(now_ms: float, to: int = ANY) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for m: Dictionary in _queue:
		if (to == ANY or int(m["to"]) == to) and float(m["at"]) <= now_ms:
			due.append(m)
		else:
			rest.append(m)
	_queue = rest
	due.sort_custom(_arrives_before)
	var out: Array[Dictionary] = []
	for m: Dictionary in due:
		if int(m["channel"]) == NetTransport.CHANNEL_FAST:
			var key := _key(int(m["from"]), int(m["to"]))
			if int(m["seq"]) < int(_fast_seq.get(key, 0)):
				continue
			_fast_seq[key] = int(m["seq"])
		out.append({"from": m["from"], "to": m["to"], "channel": m["channel"], "bytes": m["bytes"]})
	return out


## Forgets every message from or to peer_id (it left).
func drop_peer(peer_id: int) -> void:
	_queue = _queue.filter(func(m: Dictionary) -> bool:
		return int(m["from"]) != peer_id and int(m["to"]) != peer_id)


func in_flight() -> int:
	return _queue.size()


static func _arrives_before(a: Dictionary, b: Dictionary) -> bool:
	var ta := float(a["at"])
	var tb := float(b["at"])
	return ta < tb or (ta == tb and int(a["seq"]) < int(b["seq"]))


static func _key(from: int, to: int) -> String:
	return "%d>%d" % [from, to]
