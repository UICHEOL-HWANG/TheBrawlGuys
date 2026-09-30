class_name InputTrack
extends RefCounted
## One slot's per-tick inputs, run-length encoded (platform A7): only the ticks where the packed
## frame changes are kept. Binary form: "BGIL", u8 FORMAT_VERSION, varint frame count, varint run
## count, one varint start-tick delta per run, then the runs' code bytes plane by plane (all move_x
## bytes, all move_z bytes, all button bytes; InputCodec). Planes and small deltas gzip well.

const MAGIC := "BGIL"
const FORMAT_VERSION := 1
## Magic, version and two one-byte varints: the shortest (empty) track.
const HEADER_BYTES := 7
const CODE_BYTES := 3
## Decoder guard: about 77 hours at 60 Hz, far beyond any match.
const MAX_FRAMES := 1 << 24
const MAX_AXIS_BYTE := 2 * InputCodec.AXIS_OFFSET
const MAX_BUTTONS := (InputCodec.GRAB << 1) - 1

var _frame_count: int = 0
var _starts := PackedInt32Array()
var _codes := PackedInt32Array()


func record(frame: InputFrame) -> void:
	record_code(InputCodec.pack(frame))


func record_code(code: int) -> void:
	if _codes.is_empty() or _codes[_codes.size() - 1] != code:
		_starts.append(_frame_count)
		_codes.append(code)
	_frame_count += 1


func frame_count() -> int:
	return _frame_count


func run_count() -> int:
	return _codes.size()


## Packed frame at a tick (NEUTRAL outside the recording).
func code_at(tick: int) -> int:
	if tick < 0 or tick >= _frame_count:
		return InputCodec.NEUTRAL
	return _codes[_starts.bsearch(tick, false) - 1]


## Every tick's packed frame, in order.
func codes() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_frame_count)
	for r: int in _codes.size():
		var end := _starts[r + 1] if r + 1 < _starts.size() else _frame_count
		for t: int in range(_starts[r], end):
			out[t] = _codes[r]
	return out


func to_bytes() -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_data(MAGIC.to_ascii_buffer())
	buf.put_u8(FORMAT_VERSION)
	VarInt.put(buf, _frame_count)
	VarInt.put(buf, _codes.size())
	for r: int in _codes.size():
		VarInt.put(buf, _starts[r] - (_starts[r - 1] if r > 0 else 0))
	for plane: int in CODE_BYTES:
		for code: int in _codes:
			buf.put_u8((code >> (8 * plane)) & InputCodec.BYTE_MASK)
	return buf.data_array


## null when the bytes are not a well-formed track of this format version.
static func from_bytes(bytes: PackedByteArray) -> InputTrack:
	if bytes.size() < HEADER_BYTES or bytes.slice(0, MAGIC.length()).get_string_from_ascii() != MAGIC:
		return null
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(MAGIC.length())
	if buf.get_u8() != FORMAT_VERSION:
		return null
	var frames := VarInt.take(buf)
	var runs := VarInt.take(buf)
	if frames < 0 or runs < 0 or frames > MAX_FRAMES or (runs == 0) != (frames == 0) or runs > frames:
		return null
	var track := InputTrack.new()
	if not track._read_starts(buf, runs, frames) or buf.get_available_bytes() != runs * CODE_BYTES:
		return null
	track._codes.resize(runs)
	for plane: int in CODE_BYTES:
		var limit := MAX_BUTTONS if plane == CODE_BYTES - 1 else MAX_AXIS_BYTE
		for r: int in runs:
			var b := buf.get_u8()
			if b > limit:
				return null
			track._codes[r] |= b << (8 * plane)
	track._frame_count = frames
	return track if track._is_canonical() else null


## Adjacent runs must differ (the encoder never writes a run that repeats the previous code).
func _is_canonical() -> bool:
	for r: int in range(1, _codes.size()):
		if _codes[r] == _codes[r - 1]:
			return false
	return true


## Run starts from varint deltas: the first run starts at tick 0, later ones strictly after.
func _read_starts(buf: StreamPeerBuffer, runs: int, frames: int) -> bool:
	var tick := 0
	for r: int in runs:
		var delta := VarInt.take(buf)
		if delta < 0 or (r == 0) != (delta == 0):
			return false
		tick += delta
		if tick >= frames:
			return false
		_starts.append(tick)
	return true
