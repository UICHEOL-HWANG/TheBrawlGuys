class_name Uuid
extends RefCounted
## RFC 4122 version-4 UUID strings (device_id, match ids). Random bytes come from Crypto unless
## a test passes its own 16 bytes.

const BYTE_COUNT := 16


static func v4(bytes: PackedByteArray = PackedByteArray()) -> String:
	var b := bytes if bytes.size() == BYTE_COUNT else Crypto.new().generate_random_bytes(BYTE_COUNT)
	b = b.duplicate()
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var hex := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
			hex.substr(16, 4), hex.substr(20, 12)]
