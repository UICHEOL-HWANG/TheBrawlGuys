extends RefCounted
## Test double for WebRTCPeerConnection (same method and signal names, duck typed by
## WebRtcPeerLink). create_offer / an offer given to set_remote_description emit a description
## at once; link() pairs two fakes so channel i of one delivers into channel i of the other.

signal session_description_created(type: String, sdp: String)
signal ice_candidate_created(media: String, index: int, name: String)

const FakeChannel := preload("res://tests/unit/support/fake_rtc_channel.gd")

var ice: Dictionary = {}
var channels: Array = []
var options: Array[Dictionary] = []
var local: Array = []
var remote: Array = []
var candidates: Array = []
var connection_state: int = WebRTCPeerConnection.STATE_CONNECTING
var init_error: Error = OK
var closed: bool = false


func initialize(config: Dictionary) -> Error:
	ice = config
	return init_error


func create_data_channel(label: String, opts: Dictionary) -> Object:
	var ch := FakeChannel.new()
	ch.label = label
	channels.append(ch)
	options.append(opts)
	return ch


func create_offer() -> Error:
	session_description_created.emit("offer", "sdp-offer")
	return OK


func set_remote_description(type: String, sdp: String) -> Error:
	remote.append([type, sdp])
	if type == "offer":
		session_description_created.emit("answer", "sdp-answer")
	return OK


func set_local_description(type: String, sdp: String) -> Error:
	local.append([type, sdp])
	return OK


func add_ice_candidate(mid: String, index: int, name: String) -> Error:
	candidates.append([mid, index, name])
	return OK


func poll() -> Error:
	return OK


func get_connection_state() -> int:
	return connection_state


func close() -> void:
	closed = true


## Connects both fakes: channels deliver to each other and every channel opens.
static func link(a: RefCounted, b: RefCounted) -> void:
	for i: int in a.get("channels").size():
		var ca: Object = a.get("channels")[i]
		var cb: Object = b.get("channels")[i]
		ca.set("peer", cb)
		cb.set("peer", ca)
		ca.set("ready_state", WebRTCDataChannel.STATE_OPEN)
		cb.set("ready_state", WebRTCDataChannel.STATE_OPEN)
	a.set("connection_state", WebRTCPeerConnection.STATE_CONNECTED)
	b.set("connection_state", WebRTCPeerConnection.STATE_CONNECTED)
