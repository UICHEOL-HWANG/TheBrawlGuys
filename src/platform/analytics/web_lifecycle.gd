class_name WebLifecycle
extends RefCounted
## Page lifecycle for the Analytics autoload in web exports. Browsers never send
## NOTIFICATION_WM_CLOSE_REQUEST or APPLICATION_PAUSED and cancel open fetches when a tab closes,
## so this listens to the page's visibilitychange and pagehide through JavaScriptBridge (the web
## export has no thread support, so callbacks run synchronously inside the JS event) and sends
## what is queued with navigator.sendBeacon, which the browser delivers after the page is gone.
## Only does anything when OS.has_feature("web").

var _on_hidden: Callable
var _on_visible: Callable
## The JavaScriptObject callbacks must stay referenced or the JS side calls freed objects.
var _callbacks: Array = []


static func is_web() -> bool:
	return OS.has_feature("web")


## on_hidden(): tab hidden or page unloading (may come twice: visibilitychange then pagehide).
## on_visible(): tab shown again. Returns false outside web exports.
func attach(on_hidden: Callable, on_visible: Callable) -> bool:
	if not is_web():
		return false
	_on_hidden = on_hidden
	_on_visible = on_visible
	var visibility := JavaScriptBridge.create_callback(_on_visibility)
	var page_hide := JavaScriptBridge.create_callback(func(_args: Array) -> void: _on_hidden.call())
	_callbacks = [visibility, page_hide]
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", visibility)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", page_hide)
	return true


## AnalyticsClient.beacon_flush sender: true when the browser accepted the beacon.
static func send_beacon(url: String, body: String) -> bool:
	if not is_web():
		return false
	return bool(JavaScriptBridge.get_interface("navigator").sendBeacon(url, body))


func _on_visibility(_args: Array) -> void:
	if String(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden":
		_on_hidden.call()
	else:
		_on_visible.call()
