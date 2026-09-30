class_name SupabaseSession
extends RefCounted
## A signed-in Supabase Auth session (platform A3/A4). expires_at is unix seconds.

var access_token: String
var refresh_token: String
var expires_at: int
var user_id: String


func _init(access: String = "", refresh: String = "", expires: int = 0, user: String = "") -> void:
	access_token = access
	refresh_token = refresh
	expires_at = expires
	user_id = user


func is_expiring(now_s: int, margin_s: int) -> bool:
	return now_s + margin_s >= expires_at


## From an /auth/v1/token response; null when a field is missing.
static func from_token_response(data: Variant, now_s: int) -> SupabaseSession:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var user: Variant = d.get("user")
	if not (d.get("access_token") is String and d.get("refresh_token") is String and user is Dictionary):
		return null
	var user_id: Variant = (user as Dictionary).get("id")
	if not (user_id is String):
		return null
	var expires := int(d.get("expires_at", now_s + int(d.get("expires_in", 0))))
	return SupabaseSession.new(d["access_token"], d["refresh_token"], expires, user_id)


func to_dict() -> Dictionary:
	return {"access_token": access_token, "refresh_token": refresh_token, "expires_at": expires_at,
		"user_id": user_id}


static func from_dict(d: Dictionary) -> SupabaseSession:
	for key: String in ["access_token", "refresh_token", "user_id"]:
		if not (d.get(key) is String) or String(d[key]).is_empty():
			return null
	return SupabaseSession.new(d["access_token"], d["refresh_token"], int(d.get("expires_at", 0)), d["user_id"])
