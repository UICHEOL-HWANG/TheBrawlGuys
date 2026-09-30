class_name InputBlob
extends RefCounted
## Transport wrapper for one binary input track (platform A7): gzip, then base64 so the blob fits
## a PostgREST text column. ENCODING names the whole pipeline and is stored next to every blob.

const ENCODING := "bgil1+gzip+base64"
## Decompression guard: a 30-minute match of one slot changing every tick is ~760 KB raw.
const MAX_RAW_BYTES := 4 * 1024 * 1024
const BASE64_QUANTUM := 4
const GZIP_ID1 := 0x1f
const GZIP_ID2 := 0x8b

static var _pattern: RegEx = null


static func encode(raw: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## Empty when the text is not base64 of a gzip stream (checked first: the engine prints errors
## for malformed input).
static func decode(text: String) -> PackedByteArray:
	if text.is_empty() or text.length() % BASE64_QUANTUM != 0 or _base64().search(text) == null:
		return PackedByteArray()
	var packed := Marshalls.base64_to_raw(text)
	if packed.size() < 2 or packed[0] != GZIP_ID1 or packed[1] != GZIP_ID2:
		return PackedByteArray()
	return packed.decompress_dynamic(MAX_RAW_BYTES, FileAccess.COMPRESSION_GZIP)


static func _base64() -> RegEx:
	if _pattern == null:
		_pattern = RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return _pattern
