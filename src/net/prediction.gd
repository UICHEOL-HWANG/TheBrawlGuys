class_name NetPrediction
extends RefCounted
## Client-side prediction and reconciliation (PRD-NET-02, PRD §5.5). Every client tick the own
## input is applied at once to the client's World copy (and kept as pending until the host acks
## its seq); every other fighter plays its last known input held (NetInputRepeat). On a snapshot
## the World is restored to the host's state and the still-unacked inputs are re-simulated (at most
## net_max_resim_ticks). A correction is counted when the own fighter ends up more than
## net_correction_threshold away from where the prediction had it at the same tick.

## Pending inputs kept while no snapshot arrives (4 s); older ones are dropped.
const MAX_PENDING := 240

var slot: int
var corrections: int = 0
var _max_resim: int
var _threshold: float
var _seq: int = 0
## (seq, InputCodec code) of own inputs the host has not acked yet, oldest first.
var _pending: Array[Vector2i] = []
## Last known input code per slot (held only), from the newest snapshot.
var _others := PackedInt32Array()


func _init(p_slot: int, player_count: int, config: GameConfig) -> void:
	slot = p_slot
	_max_resim = config.net_max_resim_ticks
	_threshold = config.net_correction_threshold
	for i: int in player_count:
		_others.append(InputCodec.NEUTRAL)


func seq() -> int:
	return _seq


func pending_count() -> int:
	return _pending.size()


## The next own input: remembered as pending; returns every slot's frame for World.tick.
func next(own: InputFrame) -> Array[InputFrame]:
	_seq += 1
	var code := InputCodec.pack(own)
	_pending.append(Vector2i(_seq, code))
	if _pending.size() > MAX_PENDING:
		_pending.remove_at(0)
	return _frames(code)


## Up to n unacked own input codes, newest first (what INPUTS carries).
func recent_codes(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in range(_pending.size() - 1, maxi(-1, _pending.size() - 1 - n), -1):
		out.append(_pending[i].y)
	return out


## Applies a decoded SNAPSHOT to world: restore, drop acked inputs, replay the rest. Returns the
## host's state view at the snapshot tick ({} when the snapshot does not fit this World).
func reconcile(world: World, snap: Dictionary) -> Dictionary:
	var before_tick := world.tick_count
	var before_pos := own_pos(world)
	if not world.restore(snap["world"]):
		return {}
	var view := world.state_view()
	var codes: PackedInt32Array = snap["codes"]
	for i: int in mini(codes.size(), _others.size()):
		_others[i] = NetInputRepeat.held_only(codes[i])
	var acks: PackedInt32Array = snap["acks"]
	if slot < acks.size():
		_drop_acked(acks[slot])
	var truncated := _pending.size() > _max_resim
	var replay := _pending.slice(_pending.size() - _max_resim) if truncated else _pending
	for p: Vector2i in replay:
		world.tick(_frames(p.y))
	if not truncated and world.tick_count == before_tick and own_pos(world).distance_to(before_pos) > _threshold:
		corrections += 1
	return view


func own_pos(world: World) -> Vector3:
	return world.fighters[slot].pos if slot < world.fighters.size() else Vector3.ZERO


func _drop_acked(ack: int) -> void:
	var keep: Array[Vector2i] = []
	for p: Vector2i in _pending:
		if p.x > ack:
			keep.append(p)
	_pending = keep


func _frames(own_code: int) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for i: int in _others.size():
		out.append(InputCodec.unpack(own_code if i == slot else _others[i]))
	return out
