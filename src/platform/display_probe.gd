class_name DisplayProbe
extends RefCounted
## What the screen looks like right now (design.md DS-LAY-04): window size in CSS px / points,
## whether it is a touch device, and the web-only fullscreen + landscape lock request. Thin
## wrapper over DisplayServer and JavaScriptBridge; the math lives in UiScale.

## Web fallback when the engine does not report a touch screen (some mobile browsers).
const JS_TOUCH := "('ontouchstart' in window) || (navigator.maxTouchPoints || 0) > 0"
## Fullscreen first (orientation lock needs it), then lock landscape. Failures are ignored:
## iOS Safari supports neither, desktop browsers refuse the lock.
const JS_LANDSCAPE := """(function () {
	var lock = function () {
		try { var o = screen.orientation; if (o && o.lock) { o.lock('landscape').catch(function () {}); } }
		catch (e) {}
	};
	try {
		var d = document.documentElement;
		var p = d.requestFullscreen ? d.requestFullscreen({navigationUI: 'hide'}) : null;
		if (p && p.then) { p.then(lock, lock); } else { lock(); }
	} catch (e) { lock(); }
	return true;
})()"""


## Window size in CSS px (web) or points (native): physical pixels / screen scale.
static func css_size() -> Vector2:
	var px := Vector2(DisplayServer.window_get_size())
	var scale := DisplayServer.screen_get_scale()
	return px / scale if scale > 0.0 else px


static func touch_available() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval(JS_TOUCH, true))
	return false


## UiScale.profile for the current window.
static func profile() -> Dictionary:
	return UiScale.profile(css_size(), touch_available())


## Mobile web: try fullscreen + landscape lock. Call from a tap (browsers need a user gesture).
static func request_landscape() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS_LANDSCAPE, true)
