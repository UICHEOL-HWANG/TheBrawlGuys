class_name UtmParams
extends RefCounted
## Campaign parameters of the web page URL (?utm_source=slack...) for Amplitude attribution.
## The HTTP API sends no page context by itself, so Analytics reads them once at startup and
## InstallInfo.attribution turns them into utm_* / initial_utm_* user properties.

const KEYS: Array[String] = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"]
## Longer values are cut (the URL is user-editable).
const MAX_LENGTH := 100


## utm_* pairs of a query string ("?a=b&c=d" or "a=b"); empty values and other keys are dropped.
static func parse(query: String) -> Dictionary:
	var out := {}
	for pair: String in query.trim_prefix("?").split("&", false):
		var key := pair.get_slice("=", 0)
		if not KEYS.has(key):
			continue
		var value := pair.substr(key.length() + 1).replace("+", " ").uri_decode().strip_edges()
		if not value.is_empty():
			out[key] = value.left(MAX_LENGTH)
	return out


## The current page's utm_* parameters; empty outside web exports.
static func from_page() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	return parse(String(JavaScriptBridge.eval("window.location.search", true)))
