class_name KeyHintFit
extends RefCounted
## How the KeyHintHud row fits the screen width (DS-CMP-16, DS-LAY-04): full size when it fits;
## two bars that do not fit go compact (tighter gaps) when that is enough; otherwise (a small
## browser window at a large UI scale) the full-size row scales down by exactly the missing share
## (never below MIN_SCALE), gaps in proportion, so nothing is clipped or crammed. The row is laid out in a wider
## local space and drawn scaled, so the s5 safe-area margins stay s5 on screen.

const MIN_SCALE := 0.5


## Screen-px margins {left, right, top, bottom}: s5 inside the device safe area on the anchored
## edge and both sides (DS-LAY-02).
static func pads(viewport: Viewport, edge_top: bool) -> Dictionary:
	var vp := viewport.get_visible_rect()
	var safe := SafeArea.rect(viewport)
	return {
		"left": int(safe.position.x - vp.position.x) + DS.S5, "right": int(vp.end.x - safe.end.x) + DS.S5,
		"bottom": 0 if edge_top else int(vp.end.y - safe.end.y) + DS.S5,
		"top": int(safe.position.y - vp.position.y) + DS.S5 if edge_top else 0,
	}


## Row scale for bars needing `needed` px in `width` px (1 = fits).
static func scale_for(needed: float, width: float) -> float:
	if needed <= width or needed <= 0.0:
		return 1.0
	return maxf(width / needed, MIN_SCALE)


## Applies `scale` to the margin anchored across the viewport (top or bottom edge): local width
## grows by 1 / scale, the safe-area pads are divided so they stay the same on screen, and the
## pivot sits on the anchored edge.
static func apply(margin: MarginContainer, pads: Dictionary, scale: float, edge_top: bool, vp_width: float) -> void:
	margin.scale = Vector2.ONE * scale
	margin.offset_right = vp_width / scale - vp_width
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(round(float(pads.get(side, 0)) / scale)))
	margin.pivot_offset = Vector2(0.0, 0.0 if edge_top else margin.size.y)
