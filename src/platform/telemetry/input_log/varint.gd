class_name VarInt
extends RefCounted
## Unsigned LEB128 integers (platform A7): 7 bits per byte, high bit = more bytes follow. Small
## numbers (tick deltas, counts) take one byte, which is what makes the input log compact.

const PAYLOAD_BITS := 7
const PAYLOAD_MASK := 0x7F
const MORE := 0x80
## A u32 needs at most five bytes.
const MAX_BYTES := 5


static func put(buf: StreamPeerBuffer, value: int) -> void:
	var v := maxi(value, 0)
	while v > PAYLOAD_MASK:
		buf.put_u8((v & PAYLOAD_MASK) | MORE)
		v >>= PAYLOAD_BITS
	buf.put_u8(v)


## -1 when the buffer ends early or the value is longer than MAX_BYTES.
static func take(buf: StreamPeerBuffer) -> int:
	var value := 0
	for i: int in MAX_BYTES:
		if buf.get_position() >= buf.get_size():
			return -1
		var b := buf.get_u8()
		value |= (b & PAYLOAD_MASK) << (PAYLOAD_BITS * i)
		if b & MORE == 0:
			return value
	return -1
