class_name WidthFit
extends RefCounted
## Last-resort width fit for a full-screen block (design.md DS-LAY-04): when `content` is wider
## than the screen minus s6 side margins (an iPhone SE in landscape is about 1200 logical px), the
## full-rect `holder` (a plain Control child, never inside a container: containers reset their
## children's scale) is laid out 1 / scale larger and drawn at scale from its top-left, so it still
## covers its parent minus `bottom_reserve` (a footer) and the content shrinks by exactly the
## missing share (never below KeyHintFit.MIN_SCALE). Elsewhere it stays at scale 1. Refits when
## the content or the parent (the screen) resizes.

const RESERVE_META := &"width_fit_reserve"


static func watch(holder: Control, content: Control, bottom_reserve: float = 0.0) -> void:
	holder.set_meta(RESERVE_META, bottom_reserve)
	var refit := _refit.bind(holder, content)
	for source: Control in [content, holder.get_parent_control()]:
		if source != null and not source.resized.is_connected(refit):
			source.resized.connect(refit)  # sizes arrive after the first layout; screens rotate
	_refit(holder, content)


static func _refit(holder: Control, content: Control) -> void:
	var parent := holder.get_parent_area_size()
	var area := Vector2(parent.x, parent.y - float(holder.get_meta(RESERVE_META, 0.0)))
	var need := content.get_combined_minimum_size().x
	var s := clampf((area.x - DS.S6 * 2) / need, KeyHintFit.MIN_SCALE, 1.0) if need > 0.0 else 1.0
	holder.pivot_offset = Vector2.ZERO
	holder.scale = Vector2.ONE * s
	holder.offset_right = area.x / s - parent.x
	holder.offset_bottom = area.y / s - parent.y
