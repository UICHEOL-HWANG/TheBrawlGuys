class_name WebRtcPeerLink
extends RefCounted
## One WebRTC connection to a remote peer (Phase 6 online): a WebRTCPeerConnection with two
## negotiated data channels — NetTransport.CHANNEL_FAST (id 0, unreliable ordered) and
## CHANNEL_RELIABLE (id 1, reliable ordered). The offerer calls offer(); the answerer just feeds
## the remote offer to set_remote() (Godot then creates the answer). Local descriptions and ICE
## candidates come out as signals for the signaling layer. `peer` is duck typed so tests can pass
## a fake with the same methods and signals.

signal description_ready(type: String, sdp: String)
signal candidate_ready(mid: String, index: int, name: String)

## CONNECTING also covers a briefly "disconnected" ICE state (it may recover).
enum Status { NEW, CONNECTING, OPEN, FAILED, CLOSED }

var _peer: Object
var _channels: Array[Object] = []
var _status: Status = Status.NEW


func _init(peer: Object) -> void:
	_peer = peer


## Initializes the connection with ice ({"iceServers": [...]}) and creates both channels.
func setup(ice: Dictionary) -> Error:
	var err: Error = _peer.call("initialize", ice)
	if err != OK:
		_status = Status.FAILED
		return err
	_peer.connect("session_description_created", _on_description)
	_peer.connect("ice_candidate_created", _on_candidate)
	for channel: int in [NetTransport.CHANNEL_FAST, NetTransport.CHANNEL_RELIABLE]:
		var ch: Object = _peer.call("create_data_channel", WebRtcSupport.channel_label(channel),
				WebRtcSupport.channel_options(channel))
		if ch == null:
			_status = Status.FAILED
			return ERR_CANT_CREATE
		_channels.append(ch)
	_status = Status.CONNECTING
	return OK


func offer() -> Error:
	return _peer.call("create_offer")


func set_remote(type: String, sdp: String) -> Error:
	return _peer.call("set_remote_description", type, sdp)


func add_candidate(mid: String, index: int, name: String) -> Error:
	return _peer.call("add_ice_candidate", mid, index, name)


## Pumps the connection and refreshes status(); call once per frame.
func poll() -> void:
	if _status == Status.NEW or _status == Status.FAILED or _status == Status.CLOSED:
		return
	_peer.call("poll")
	var state := int(_peer.call("get_connection_state"))
	if state == WebRTCPeerConnection.STATE_FAILED:
		_status = Status.FAILED
	elif state == WebRTCPeerConnection.STATE_CLOSED:
		_status = Status.CLOSED
	else:
		_status = Status.OPEN if _channels_open() else Status.CONNECTING


func status() -> Status:
	return _status


func is_open() -> bool:
	return _status == Status.OPEN


func send(channel: int, bytes: PackedByteArray) -> Error:
	if not is_open() or channel < 0 or channel >= _channels.size():
		return ERR_UNAVAILABLE
	return _channels[channel].call("put_packet", bytes)


## Packets received on channel since the last call.
func drain(channel: int) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if channel < 0 or channel >= _channels.size():
		return out
	var ch := _channels[channel]
	while int(ch.call("get_available_packet_count")) > 0:
		out.append(ch.call("get_packet"))
	return out


func close() -> void:
	for ch: Object in _channels:
		ch.call("close")
	if _status != Status.NEW:
		_peer.call("close")
	for pair: Array in [["session_description_created", _on_description], ["ice_candidate_created", _on_candidate]]:
		if _peer.is_connected(pair[0], pair[1]):
			_peer.disconnect(pair[0], pair[1])  # breaks the peer ↔ link reference cycle
	_status = Status.CLOSED


func _channels_open() -> bool:
	for ch: Object in _channels:
		if int(ch.call("get_ready_state")) != WebRTCDataChannel.STATE_OPEN:
			return false
	return not _channels.is_empty()


func _on_description(type: String, sdp: String) -> void:
	_peer.call("set_local_description", type, sdp)
	description_ready.emit(type, sdp)


func _on_candidate(mid: String, index: int, name: String) -> void:
	candidate_ready.emit(mid, index, name)
