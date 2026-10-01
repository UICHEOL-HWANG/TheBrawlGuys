class_name NetRemoteSlot
extends RefCounted
## Host-side state of one remote player's slot (HostSession): which peer plays it, the client
## inputs received but not yet applied (seq -> InputCodec code, at most buffer_max), the newest
## applied seq (the ack sent back in snapshots), and whether it is connected or taken over by a bot.
## A backlog (a burst after a stall) drains: above DRAIN_ABOVE queued inputs two are applied per
## tick, and inputs dropped on overflow hand their presses on, so no jump / attack / grab is lost.

## Queued inputs above which the host applies two per tick (NetClockSync aims for ~2).
const DRAIN_ABOVE := 4

var slot: int
var peer_id: int = 0
var connected: bool = false
var applied_seq: int = 0
var last_code: int = InputCodec.NEUTRAL
## Clock ms when the peer dropped (-1 = connected or never joined).
var left_at_ms: int = -1
var is_bot: bool = false
## Ticks the host had no input from a connected client / inputs folded into a neighbour.
var starved: int = 0
var merged: int = 0
var _queue: Dictionary = {}
var _buffer_max: int


func _init(p_slot: int, buffer_max: int) -> void:
	slot = p_slot
	_buffer_max = maxi(buffer_max, 1)


## A new peer (a reconnect gets a new id) counts its input seqs from 1 again.
func bind(p_peer_id: int) -> void:
	if p_peer_id != peer_id:
		applied_seq = 0
		_queue.clear()
	peer_id = p_peer_id
	connected = true
	left_at_ms = -1


func drop(now_ms: int) -> void:
	connected = false
	left_at_ms = now_ms
	_queue.clear()


## A slot a new HELLO may take: never bound, or dropped and still inside its grace period.
func is_open() -> bool:
	return not is_bot and not connected


## codes[i] is the input for seq - i; only seqs not applied yet are kept.
func receive(seq: int, codes: PackedInt32Array) -> void:
	for i: int in codes.size():
		var s := seq - i
		if s > applied_seq and not _queue.has(s):
			_queue[s] = codes[i]
	while _queue.size() > _buffer_max:
		var dropped := int(_queue[_oldest()])
		_queue.erase(_oldest())
		var next := _oldest()
		_queue[next] = NetInputRepeat.add_presses(int(_queue[next]), dropped)
		merged += 1


## The input for this host tick: the oldest queued one (two folded together while draining a
## backlog), else the last one held (see NetInputRepeat).
func next_code() -> int:
	if _queue.is_empty():
		if connected:
			starved += 1
		return NetInputRepeat.held_only(last_code)
	var code := _pop_oldest()
	if _queue.size() >= DRAIN_ABOVE:
		code = NetInputRepeat.add_presses(_pop_oldest(), code)
		merged += 1
	last_code = code
	return last_code


func queued() -> int:
	return _queue.size()


func _pop_oldest() -> int:
	var s := _oldest()
	var code := int(_queue[s])
	_queue.erase(s)
	applied_seq = s
	return code


func _oldest() -> int:
	var keys: Array = _queue.keys()
	return int(keys.min())
