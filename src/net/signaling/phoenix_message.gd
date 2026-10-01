class_name PhoenixMessage
extends RefCounted
## Phoenix channel frames for Supabase Realtime (serializer vsn 1.0.0: one JSON object per text
## frame — {topic, event, payload, ref, join_ref}). Only what room signaling needs: join, leave,
## heartbeat and broadcast. Used by RealtimeChannel (Phase 6 online, no Supabase SDK in Godot).

const VSN := "1.0.0"
const TOPIC_PREFIX := "realtime:"
const HEARTBEAT_TOPIC := "phoenix"
const EV_JOIN := "phx_join"
const EV_LEAVE := "phx_leave"
const EV_REPLY := "phx_reply"
const EV_ERROR := "phx_error"
const EV_CLOSE := "phx_close"
const EV_HEARTBEAT := "heartbeat"
const EV_BROADCAST := "broadcast"
const STATUS_OK := "ok"


## One frame as text. ref / join_ref may be "" (Phoenix sends null then).
static func encode(topic: String, event: String, payload: Dictionary, ref: String = "",
		join_ref: String = "") -> String:
	return JSON.stringify({
		"topic": topic, "event": event, "payload": payload,
		"ref": null if ref.is_empty() else ref, "join_ref": null if join_ref.is_empty() else join_ref,
	})


## {topic, event, payload: Dictionary, ref: String} or {} when text is not a Phoenix frame.
static func decode(text: String) -> Dictionary:
	var data: Variant = JsonSafe.parse(text)
	if not (data is Dictionary):
		return {}
	var d: Dictionary = data
	if not (d.get("topic") is String and d.get("event") is String):
		return {}
	var payload: Variant = d.get("payload", {})
	return {
		"topic": d["topic"], "event": d["event"], "payload": payload if payload is Dictionary else {},
		"ref": _ref(d.get("ref")),
	}


## Join with a broadcast-only config (no self echo, no acks, no presence). access_token = the
## signed-in user's JWT ("" = anon).
static func join(topic: String, ref: String, access_token: String) -> String:
	var payload := {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""},
		"private": false}}
	if not access_token.is_empty():
		payload["access_token"] = access_token
	return encode(topic, EV_JOIN, payload, ref, ref)


static func heartbeat(ref: String) -> String:
	return encode(HEARTBEAT_TOPIC, EV_HEARTBEAT, {}, ref)


static func broadcast(topic: String, event: String, payload: Dictionary, ref: String, join_ref: String) -> String:
	return encode(topic, EV_BROADCAST, {"type": EV_BROADCAST, "event": event, "payload": payload}, ref, join_ref)


static func leave(topic: String, ref: String, join_ref: String) -> String:
	return encode(topic, EV_LEAVE, {}, ref, join_ref)


static func topic_for(room: String) -> String:
	return TOPIC_PREFIX + room


## wss://<project>.supabase.co/realtime/v1/websocket?apikey=<anon>&vsn=1.0.0 from the REST url.
static func socket_url(supabase_url: String, anon_key: String) -> String:
	var base := supabase_url.trim_suffix("/")
	if base.begins_with("https://"):
		base = "wss://" + base.substr("https://".length())
	elif base.begins_with("http://"):
		base = "ws://" + base.substr("http://".length())
	return "%s/realtime/v1/websocket?apikey=%s&vsn=%s" % [base, anon_key.uri_encode(), VSN]


## True for a phx_reply whose status is ok.
static func is_ok_reply(msg: Dictionary) -> bool:
	return msg.get("event") == EV_REPLY and (msg["payload"] as Dictionary).get("status") == STATUS_OK


static func _ref(v: Variant) -> String:
	if v is String:
		return v
	if v is float or v is int:
		return str(int(v))
	return ""
