class_name LoopbackTransport
extends NetTransport
## One peer of a LoopbackHub (tests, local debugging). Messages arrive after the hub's simulated
## latency once LoopbackHub.advance() has moved the clock far enough; see NetDelayLine.

var _hub: LoopbackHub
var _id: int


func _init(hub: LoopbackHub, id: int) -> void:
	_hub = hub
	_id = id


func local_id() -> int:
	return _id


func peers() -> PackedInt32Array:
	return _hub.peers_of(_id)


func send(peer_id: int, channel: int, bytes: PackedByteArray) -> void:
	_hub.route(_id, peer_id, channel, bytes)


func poll() -> Array[Dictionary]:
	return _hub.deliver(_id)


func rtt_ms(peer_id: int) -> float:
	return _hub.rtt_ms() if peers().has(peer_id) else -1.0


func close() -> void:
	_hub.disconnect_peer(_id)
