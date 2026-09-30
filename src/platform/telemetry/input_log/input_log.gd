class_name InputLog
extends RefCounted
## Replay-grade input log of one match (platform A7, analytics-strategy §1 L0): one InputTrack per
## slot, humans and bots alike, one frame per sim tick from tick 0. rows() are the match_inputs
## rows; from_rows() restores the log so a headless World can replay the match exactly.

var _tracks: Array[InputTrack] = []
## Lazily expanded per-slot codes for inputs_at() (replay reads every tick in order).
var _expanded: Array[PackedInt32Array] = []


func _init(slot_count: int = 0) -> void:
	for i: int in slot_count:
		_tracks.append(InputTrack.new())


## The inputs World.tick() got, in slot order. A missing slot is neutral, as in World.
func record(inputs: Array) -> void:
	for slot: int in _tracks.size():
		var f: InputFrame = inputs[slot] if slot < inputs.size() else null
		_tracks[slot].record_code(InputCodec.pack(f) if f != null else InputCodec.NEUTRAL)
	_expanded.clear()


func slot_count() -> int:
	return _tracks.size()


func frame_count() -> int:
	return _tracks[0].frame_count() if not _tracks.is_empty() else 0


func track(slot: int) -> InputTrack:
	return _tracks[slot]


## Fresh InputFrames for one tick, one per slot.
func inputs_at(tick: int) -> Array[InputFrame]:
	if _expanded.size() != _tracks.size():
		_expanded.clear()
		for t: InputTrack in _tracks:
			_expanded.append(t.codes())
	var out: Array[InputFrame] = []
	for codes: PackedInt32Array in _expanded:
		out.append(InputCodec.unpack(codes[tick]) if tick < codes.size() else InputFrame.neutral())
	return out


## match_inputs rows: {match_id, slot, encoding, frames (text), frame_count}; none before tick 0.
func rows(match_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if frame_count() == 0:
		return out
	for slot: int in _tracks.size():
		out.append({"match_id": match_id, "slot": slot, "encoding": InputBlob.ENCODING,
			"frames": InputBlob.encode(_tracks[slot].to_bytes()), "frame_count": _tracks[slot].frame_count()})
	return out


## null when a row is malformed, uses another encoding, or the slots disagree on frame count.
static func from_rows(rows: Array) -> InputLog:
	var by_slot := {}
	for r: Variant in rows:
		var row: Dictionary = r if r is Dictionary else {}
		if String(row.get("encoding", "")) != InputBlob.ENCODING:
			return null
		var track := InputTrack.from_bytes(InputBlob.decode(String(row.get("frames", ""))))
		if track == null or track.frame_count() != int(row.get("frame_count", -1)):
			return null
		by_slot[int(row.get("slot", -1))] = track
	var log := InputLog.new()
	for slot: int in by_slot.size():
		if not by_slot.has(slot):
			return null
		var track: InputTrack = by_slot[slot]
		if track.frame_count() != (by_slot[0] as InputTrack).frame_count():
			return null
		log._tracks.append(track)
	return log
