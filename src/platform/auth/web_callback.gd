class_name WebCallback
extends RefCounted
## Web OAuth return path (platform A4): after Supabase redirects back with ?code=..., read the
## query through JavaScriptBridge and remove it from the address bar. Only works in web exports;
## elsewhere the query is empty. The PKCE verifier waits in the page origin's localStorage: it is
## written synchronously before the redirect (user:// syncs to IndexedDB asynchronously and can
## lose the write when the page navigates away at once).

const VERIFIER_KEY := "tbg_pkce_verifier"


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


## Page URL without query or hash: where a web sign-in returns (auth.redirect_web is the fallback).
func current_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return String(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))


func save_verifier(verifier: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem(%s, %s)" % [JSON.stringify(VERIFIER_KEY),
			JSON.stringify(verifier)], true)


func peek_verifier() -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("window.localStorage.getItem(%s)" % JSON.stringify(VERIFIER_KEY), true)
	return "" if v == null else String(v)


## Returns the verifier once and erases it (a code can be exchanged only once).
func take_verifier() -> String:
	var v := peek_verifier()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.removeItem(%s)" % JSON.stringify(VERIFIER_KEY), true)
	return v


## "?a=1&b=x%20y" -> {"a": "1", "b": "x y"}.
static func parse_query(search: String) -> Dictionary:
	var out := {}
	for pair: String in search.trim_prefix("?").split("&", false):
		var raw_key := pair.get_slice("=", 0)
		out[raw_key.uri_decode()] = pair.substr(raw_key.length() + 1).uri_decode() if pair.contains("=") else ""
	return out
