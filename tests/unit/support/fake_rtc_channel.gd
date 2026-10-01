extends RefCounted
## Test double for WebRTCDataChannel: put_packet delivers into the linked channel (`peer`) and
## records every packet in `sent`.

var label: String = ""
var ready_state: int = WebRTCDataChannel.STATE_CONNECTING
var peer: Object = null
var sent: Array[PackedByteArray] = []
var inbox: Array[PackedByteArray] = []


func put_packet(bytes: PackedByteArray) -> Error:
	sent.append(bytes)
	if peer != null:
		(peer.get("inbox") as Array).append(bytes)
	return OK


func get_available_packet_count() -> int:
	return inbox.size()


func get_packet() -> PackedByteArray:
	return inbox.pop_front()


func get_ready_state() -> int:
	return ready_state


func close() -> void:
	ready_state = WebRTCDataChannel.STATE_CLOSED
