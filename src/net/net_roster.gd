class_name NetRoster
extends RefCounted
## The host's remote slots (HostSession): which peer plays which "remote" slot of the MatchSetup.
## A joining peer gets the slot the lobby assigned it when free, else the first free one; a slot is
## free when nobody holds it or its player dropped and the grace period is still running (a
## reconnect, under any peer id, takes it back).

## slot -> NetRemoteSlot
var _slots: Dictionary = {}
## peer id -> slot the lobby picked for it
var _assigned: Dictionary = {}


func _init(setup: MatchSetup, buffer_max: int, peer_slots: Dictionary = {}) -> void:
	_assigned = peer_slots.duplicate()
	for s: Dictionary in setup.slots:
		if String(s["controller"]) == MatchSetup.CONTROLLER_REMOTE:
			_slots[int(s["slot"])] = NetRemoteSlot.new(int(s["slot"]), buffer_max)


func has(slot: int) -> bool:
	return _slots.has(slot)


func at(slot: int) -> NetRemoteSlot:
	return _slots.get(slot)


func all() -> Array[NetRemoteSlot]:
	var out: Array[NetRemoteSlot] = []
	var keys: Array = _slots.keys()
	keys.sort()
	for slot: int in keys:
		out.append(_slots[slot])
	return out


func connected() -> Array[NetRemoteSlot]:
	var out: Array[NetRemoteSlot] = []
	for r: NetRemoteSlot in all():
		if r.connected:
			out.append(r)
	return out


## Every remote slot has its player (the lobby's humans all said HELLO).
func all_joined() -> bool:
	return _slots.values().all(func(r: NetRemoteSlot) -> bool: return r.connected)


## The connected slot of peer, or null.
func of_peer(peer: int) -> NetRemoteSlot:
	for r: NetRemoteSlot in _slots.values():
		if r.peer_id == peer and r.connected:
			return r
	return null


## The slot peer played last, connected or dropped (null when it never had one).
func last_of_peer(peer: int) -> NetRemoteSlot:
	for r: NetRemoteSlot in _slots.values():
		if r.peer_id == peer:
			return r
	return null


## Binds peer to its slot (already held, assigned or first free); null when the room is full.
func claim(peer: int) -> NetRemoteSlot:
	var r := of_peer(peer)
	if r == null:
		r = _open_slot(peer)
	if r != null:
		r.bind(peer)
	return r


## Slots whose player is gone for at least grace_ms and no bot has taken yet.
func expired(now_ms: int, grace_ms: int) -> Array[NetRemoteSlot]:
	var out: Array[NetRemoteSlot] = []
	for r: NetRemoteSlot in all():
		if not r.connected and not r.is_bot and r.left_at_ms >= 0 and now_ms - r.left_at_ms >= grace_ms:
			out.append(r)
	return out


## Slots nobody joined start their grace period now (the match started without them).
func mark_unjoined(now_ms: int) -> void:
	for r: NetRemoteSlot in _slots.values():
		if not r.connected and r.left_at_ms < 0:
			r.left_at_ms = now_ms


## Acked input seq per slot (0 for slots that are not remote).
func acks(player_count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in player_count:
		out.append((_slots[i] as NetRemoteSlot).applied_seq if _slots.has(i) else 0)
	return out


## Inputs waiting per slot (0 for slots that are not remote), for NetClockSync.
func queued(player_count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in player_count:
		out.append((_slots[i] as NetRemoteSlot).queued() if _slots.has(i) else 0)
	return out


## An unassigned peer may take a free slot no other peer was promised, or one whose player dropped.
func _open_slot(peer: int) -> NetRemoteSlot:
	var wanted: NetRemoteSlot = _slots.get(int(_assigned.get(peer, -1)))
	if wanted != null and wanted.is_open():
		return wanted
	for r: NetRemoteSlot in all():
		if r.is_open() and (r.peer_id != 0 or not _assigned.values().has(r.slot)):
			return r
	return null
