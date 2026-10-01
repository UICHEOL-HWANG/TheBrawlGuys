class_name NetProtocol
extends RefCounted
## Online match wire format (Phase 6, online design). Every message starts with [VERSION u8, Type u8];
## a peer drops messages of another version. Inputs travel as 24-bit InputCodec codes (newest
## first, with the last N repeated so a lost packet costs nothing), world state as zstd-compressed
## WorldCodec snapshot bytes, setups and sim events as var_to_bytes (never objects).
##   HELLO   client -> host: join request
##   WELCOME host -> client: slot u8, setup dict (SetupCodec)
##   INPUTS  client -> host: newest client seq u32, count u8, codes (seq, seq-1, ...)
##   SNAPSHOT host -> all: host tick u32, slots u8, per slot (acked seq u32, last input code),
##           raw size u32, compressed World snapshot
##   EVENTS  host -> all (reliable): host tick u32, events Array
##   START / END: tick u32 / winner s32 · PING / PONG: client ms u32 · BYE: leaving

const VERSION := 1
enum Type { HELLO = 1, WELCOME, INPUTS, SNAPSHOT, EVENTS, START, END, PING, PONG, BYE }
const MAX_INPUTS := 32
const MAX_SLOTS := 4
const MAX_BLOB := 1 << 20
const COMPRESSION := FileAccess.COMPRESSION_ZSTD


static func hello() -> PackedByteArray:
	return _begin(Type.HELLO).data_array


static func welcome(slot: int, setup: Dictionary) -> PackedByteArray:
	var b := _begin(Type.WELCOME)
	b.put_u8(slot)
	_put_blob(b, var_to_bytes(setup))
	return b.data_array


## codes: newest first (codes[0] is seq's input).
static func inputs(seq: int, codes: PackedInt32Array) -> PackedByteArray:
	var b := _begin(Type.INPUTS)
	b.put_u32(seq)
	var n := mini(codes.size(), MAX_INPUTS)
	b.put_u8(n)
	for i: int in n:
		_put_code(b, codes[i])
	return b.data_array


static func snapshot(tick: int, acks: PackedInt32Array, codes: PackedInt32Array,
		world: PackedByteArray) -> PackedByteArray:
	var b := _begin(Type.SNAPSHOT)
	b.put_u32(tick)
	b.put_u8(acks.size())
	for i: int in acks.size():
		b.put_u32(acks[i])
		_put_code(b, codes[i])
	b.put_u32(world.size())
	_put_blob(b, world.compress(COMPRESSION))
	return b.data_array


static func events(tick: int, list: Array) -> PackedByteArray:
	var b := _begin(Type.EVENTS)
	b.put_u32(tick)
	_put_blob(b, var_to_bytes(list))
	return b.data_array


static func start(tick: int) -> PackedByteArray:
	return _with_u32(Type.START, tick)


static func end(winner: int) -> PackedByteArray:
	var b := _begin(Type.END)
	b.put_32(winner)
	return b.data_array


static func ping(ms: int) -> PackedByteArray:
	return _with_u32(Type.PING, ms)


static func pong(ms: int) -> PackedByteArray:
	return _with_u32(Type.PONG, ms)


static func bye() -> PackedByteArray:
	return _begin(Type.BYE).data_array


## {"type": Type, ...fields} or {} when the message is broken, of another version or unknown.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var r := NetReader.new(bytes)
	if r.u8() != VERSION:
		return {}
	var type := r.u8()
	var out := _fields(type, r)
	if not r.ok or out.is_empty() or not r.at_end():
		return {}
	out["type"] = type
	return out


static func _fields(type: int, r: NetReader) -> Dictionary:
	match type:
		Type.HELLO, Type.BYE:
			return {"ok": true}
		Type.WELCOME:
			var slot := r.u8()
			var setup: Variant = r.variant(MAX_BLOB)
			return {"slot": slot, "setup": setup} if setup is Dictionary else {}
		Type.INPUTS:
			return _read_inputs(r)
		Type.SNAPSHOT:
			return _read_snapshot(r)
		Type.EVENTS:
			var tick := r.u32()
			var list: Variant = r.variant(MAX_BLOB)
			return {"tick": tick, "events": list} if list is Array else {}
		Type.START:
			return {"tick": r.u32()}
		Type.END:
			return {"winner": r.s32()}
		Type.PING, Type.PONG:
			return {"ms": r.u32()}
	return {}


static func _read_inputs(r: NetReader) -> Dictionary:
	var seq := r.u32()
	var n := r.u8()
	if n > MAX_INPUTS:
		return {}
	var codes := PackedInt32Array()
	for i: int in n:
		codes.append(r.code())
	return {"seq": seq, "codes": codes}


static func _read_snapshot(r: NetReader) -> Dictionary:
	var tick := r.u32()
	var n := r.u8()
	if n > MAX_SLOTS:
		return {}
	var acks := PackedInt32Array()
	var codes := PackedInt32Array()
	for i: int in n:
		acks.append(r.u32())
		codes.append(r.code())
	var raw_size := r.u32()
	var packed := r.blob(MAX_BLOB)
	if not r.ok or raw_size > MAX_BLOB or packed.is_empty():
		return {}
	var world := packed.decompress(raw_size, COMPRESSION)
	if world.size() != raw_size:
		return {}
	return {"tick": tick, "acks": acks, "codes": codes, "world": world}


static func _begin(type: int) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.put_u8(VERSION)
	b.put_u8(type)
	return b


static func _with_u32(type: int, value: int) -> PackedByteArray:
	var b := _begin(type)
	b.put_u32(value)
	return b.data_array


static func _put_code(b: StreamPeerBuffer, code: int) -> void:
	b.put_u8(code & 0xFF)
	b.put_u8((code >> 8) & 0xFF)
	b.put_u8((code >> 16) & 0xFF)


static func _put_blob(b: StreamPeerBuffer, bytes: PackedByteArray) -> void:
	b.put_u32(bytes.size())
	b.put_data(bytes)
