class_name WebRtcSupport
extends RefCounted
## Can this build open WebRTC peer connections? Browsers have WebRTC built in (Web export);
## desktop and mobile need the webrtc-native GDExtension, which registers WebRTCLibPeerConnection.
## Without it Godot hands out an empty WebRTCPeerConnectionExtension that only logs errors, so the
## online menu checks here first and shows UNSUPPORTED_TEXT instead.

const NATIVE_CLASS := "WebRTCLibPeerConnection"
const UNSUPPORTED_TEXT := "이 플랫폼은 아직 온라인 미지원 (웹에서 플레이)"
## Data channel ids, negotiated on both sides (no in-band DATA_CHANNEL_OPEN).
const FAST_ID := NetTransport.CHANNEL_FAST
const RELIABLE_ID := NetTransport.CHANNEL_RELIABLE


static func available() -> bool:
	return OS.has_feature("web") or ClassDB.class_exists(NATIVE_CLASS)


## Creates a real peer connection (only call when available()).
static func new_peer() -> Object:
	return WebRTCPeerConnection.new()


## create_data_channel options per NetTransport channel: fast = unreliable ordered
## (maxRetransmits 0), reliable = reliable ordered.
static func channel_options(channel: int) -> Dictionary:
	if channel == FAST_ID:
		return {"negotiated": true, "id": FAST_ID, "maxRetransmits": 0, "ordered": true}
	return {"negotiated": true, "id": RELIABLE_ID, "ordered": true}


static func channel_label(channel: int) -> String:
	return "fast" if channel == FAST_ID else "reliable"


## {"iceServers": [...]}: public Google STUN plus the TURN servers from secrets ([net] turn_urls,
## comma separated, with turn_username / turn_credential).
static func ice_config(secrets: Secrets) -> Dictionary:
	var servers: Array = [{"urls": [Secrets.DEFAULT_STUN]}]
	if secrets != null and not secrets.turn_urls.is_empty():
		servers.append({"urls": Array(secrets.turn_urls), "username": secrets.turn_username,
			"credential": secrets.turn_credential})
	return {"iceServers": servers}
