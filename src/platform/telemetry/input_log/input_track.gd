class_name InputTrack
extends RefCounted
## One slot's per-tick inputs, run-length encoded (platform A7): only the ticks where the packed
## frame changes are kept. Binary form (little endian): "BGIL", u8 FORMAT_VERSION, u32 frame count,
## u32 run count, then per run u32 start tick + 3 code bytes (InputCodec).

const MAGIC := "BGIL"
const FORMAT_VERSION := 1
const HEADER_BYTES := 13
const RUN_BYTES := 7
const CODE_BYTES := 3

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
	buf.put_u32(_frame_count)
	buf.put_u32(_codes.size())
	for r: int in _codes.size():
		buf.put_u32(_starts[r])
		for i: int in CODE_BYTES:
			buf.put_u8((_codes[r] >> (8 * i)) & InputCodec.BYTE_MASK)
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
	var frames := buf.get_u32()
	var runs := buf.get_u32()
	if bytes.size() != HEADER_BYTES + runs * RUN_BYTES or (runs == 0) != (frames == 0):
		return null
	var track := InputTrack.new()
	for r: int in runs:
		var start := buf.get_u32()
		var code := buf.get_u8() | (buf.get_u8() << 8) | (buf.get_u8() << 16)
		var expected_first := r > 0 or start == 0
		if not expected_first or start >= frames or (r > 0 and start <= track._starts[r - 1]):
			return null
		track._starts.append(start)
		track._codes.append(code)
	track._frame_count = frames
	return track
