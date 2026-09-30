class_name WebCallback
extends RefCounted
## Web OAuth return path (platform A4): after Supabase redirects back with ?code=..., read the
## query through JavaScriptBridge and remove it from the address bar. Only works in web exports;
## elsewhere the query is empty.


func read_query() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	return parse_query(String(JavaScriptBridge.eval("window.location.search", true)))


## Replaces the URL without the query so a reload does not resubmit a used code.
func clean_url() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.history.replaceState(null, '', window.location.pathname)", true)


func redirect(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign(%s)" % JSON.stringify(url), true)
	else:
		push_error("WebCallback.redirect is web-only (%s)" % url)


## Page URL without query or hash: the fallback redirect target when auth.redirect_web is empty.
func current_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return String(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))


## "?a=1&b=x%20y" -> {"a": "1", "b": "x y"}.
static func parse_query(search: String) -> Dictionary:
	var out := {}
	for pair: String in search.trim_prefix("?").split("&", false):
		var raw_key := pair.get_slice("=", 0)
		out[raw_key.uri_decode()] = pair.substr(raw_key.length() + 1).uri_decode() if pair.contains("=") else ""
	return out
