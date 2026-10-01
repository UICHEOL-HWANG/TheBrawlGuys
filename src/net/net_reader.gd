class_name NetReader
extends RefCounted
## Bounds-checked reads over one received message (NetProtocol.decode). Any read past the end
## clears `ok` and returns 0 / empty, so a truncated or hostile message decodes to {} instead of
## garbage. Integers are little-endian (StreamPeerBuffer).

var ok: bool = true
var _b := StreamPeerBuffer.new()


func _init(bytes: PackedByteArray) -> void:
	_b.data_array = bytes


func u8() -> int:
	return _b.get_u8() if _need(1) else 0


func u32() -> int:
	return _b.get_u32() if _need(4) else 0


func s32() -> int:
	return _b.get_32() if _need(4) else 0


## A 24-bit InputCodec code.
func code() -> int:
	if not _need(3):
		return 0
	var lo := _b.get_u8()
	var mid := _b.get_u8()
	var hi := _b.get_u8()
	return lo | (mid << 8) | (hi << 16)


## u32 length + that many bytes; empty (and not ok) when the length is over max_size.
func blob(max_size: int) -> PackedByteArray:
	var size := u32()
	if size > max_size or not _need(size):
		ok = false
		return PackedByteArray()
	var got: Array = _b.get_data(size)
	return got[1]


## A Variant from a blob (bytes_to_var never decodes objects); null when broken.
func variant(max_size: int) -> Variant:
	var bytes := blob(max_size)
	if not ok or bytes.is_empty():
		ok = false
		return null
	return bytes_to_var(bytes)


func at_end() -> bool:
	return _b.get_available_bytes() == 0


func _need(n: int) -> bool:
	if not ok or n < 0 or _b.get_available_bytes() < n:
		ok = false
		return false
	return true
