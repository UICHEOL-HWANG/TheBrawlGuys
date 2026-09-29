class_name SafeArea
extends RefCounted
## The part of the viewport clear of notches and gesture bars (design.md DS-LAY-02, Phase 1
## carry-over). Mobile only: the device safe area is mapped into viewport coordinates; desktop
## windows use the whole viewport.


static func rect(viewport: Viewport) -> Rect2:
	var vp := viewport.get_visible_rect()
	if not OS.has_feature("mobile"):
		return vp
	var screen := Vector2(DisplayServer.screen_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or screen.y <= 0.0 or sa.size.x <= 0 or sa.size.y <= 0:
		return vp
	var scale := vp.size / screen
	return Rect2(Vector2(sa.position) * scale, Vector2(sa.size) * scale).intersection(vp)
