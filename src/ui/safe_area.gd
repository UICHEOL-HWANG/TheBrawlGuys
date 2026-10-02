class_name SafeArea
extends RefCounted
## The part of the viewport clear of notches and gesture bars (design.md DS-LAY-02, Phase 1
## carry-over). Native mobile maps the device safe area into viewport coordinates; the web reads
## the browser's env(safe-area-inset-*) from the shell's #safe-probe (the page covers the whole
## screen, viewport-fit=cover); desktop windows use the whole viewport.

## "top,right,bottom,left,innerWidth,innerHeight" in CSS px, or "" without the probe.
const JS_INSETS := """(function () {
	var e = document.getElementById('safe-probe');
	if (!e) { return ''; }
	var s = getComputedStyle(e);
	return [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft].map(function (v) {
		return parseFloat(v) || 0;
	}).concat([window.innerWidth, window.innerHeight]).join(',');
})()"""


static func rect(viewport: Viewport) -> Rect2:
	var vp := viewport.get_visible_rect()
	if OS.has_feature("web"):
		return from_css_insets(vp, String(JavaScriptBridge.eval(JS_INSETS, true)))
	if not OS.has_feature("mobile"):
		return vp
	var screen := Vector2(DisplayServer.screen_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or screen.y <= 0.0 or sa.size.x <= 0 or sa.size.y <= 0:
		return vp
	var scale := vp.size / screen
	return Rect2(Vector2(sa.position) * scale, Vector2(sa.size) * scale).intersection(vp)


## vp shrunk by the JS_INSETS reading (CSS px scaled to the viewport); vp itself when unreadable.
static func from_css_insets(vp: Rect2, reading: String) -> Rect2:
	var parts := reading.split(",")
	if parts.size() != 6 or float(parts[4]) <= 0.0 or float(parts[5]) <= 0.0:
		return vp
	var scale := vp.size / Vector2(float(parts[4]), float(parts[5]))
	var top := float(parts[0]) * scale.y
	var right := float(parts[1]) * scale.x
	var bottom := float(parts[2]) * scale.y
	var left := float(parts[3]) * scale.x
	var out := Rect2(vp.position + Vector2(left, top), vp.size - Vector2(left + right, top + bottom))
	return out if out.size.x > 0.0 and out.size.y > 0.0 else vp
