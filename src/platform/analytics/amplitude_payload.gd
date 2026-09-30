class_name AmplitudePayload
extends RefCounted
## Amplitude HTTP API v2 shapes (platform A2): one event object and the request body.
## https://amplitude.com/docs/apis/analytics/http-v2


## Top-level fields Amplitude requires as JSON integers ("time": 1.7e12 with ".0" is HTTP 400).
const INT_FIELDS: Array[String] = ["time", "session_id", "event_id"]


## identity: {device_id, user_id, session_id}; context: {platform, os_name, app_version, language}.
static func event(event_name: String, props: Dictionary, identity: Dictionary, time_ms: int,
		insert_id: String, context: Dictionary, user_props: Dictionary) -> Dictionary:
	var e := {
		"event_type": event_name,
		"device_id": identity["device_id"],
		"session_id": identity["session_id"],
		"time": time_ms,
		"insert_id": insert_id,
		"event_properties": props,
	}
	var user_id := String(identity.get("user_id", ""))
	if not user_id.is_empty():
		e["user_id"] = user_id
	if not user_props.is_empty():
		e["user_properties"] = user_props
	for key: String in context:
		e[key] = context[key]
	return e


static func body(api_key: String, events: Array[Dictionary]) -> String:
	return JSON.stringify({"api_key": api_key, "events": events})


## An event read back from JSON (numbers come back as floats) with its integer fields restored.
static func with_int_fields(e: Dictionary) -> Dictionary:
	var out := e.duplicate()
	for key: String in INT_FIELDS:
		if out.has(key) and (out[key] is float or out[key] is int):
			out[key] = int(out[key])
	return out
