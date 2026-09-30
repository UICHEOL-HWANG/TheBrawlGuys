class_name UiMotion
extends RefCounted
## Motion tokens (design.md DS-TOK-05) as ready-made tweens, so every UI transition uses the
## same timings: fast = press, base = panels, squish = pops and banners, slow = screens.

enum Token { FAST, BASE, SQUISH, SLOW }

const FADE_META := &"ui_motion_fade"


static func spec(token: int) -> Dictionary:
	match token:
		Token.FAST:
			return {"duration": DS.MOTION_FAST, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}
		Token.SQUISH:
			return {"duration": DS.MOTION_SQUISH, "trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT}
		Token.SLOW:
			return {"duration": DS.MOTION_SLOW, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT}
	return {"duration": DS.MOTION_BASE, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}


static func pop_in(node: Control, from_scale: float) -> Tween:
	_cancel_fade(node)
	node.visible = true
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	_step(tw, node, "modulate:a", 1.0, Token.BASE)
	return tw


static func fade_out(node: CanvasItem) -> Tween:
	_cancel_fade(node)
	var tw := node.create_tween()
	_step(tw, node, "modulate:a", 0.0, Token.BASE)
	tw.tween_callback(func() -> void: node.visible = false)
	node.set_meta(FADE_META, tw)
	return tw


static func bump(node: Control, from_scale: float) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	var tw := node.create_tween()
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


static func release(node: Control) -> Tween:
	var tw := node.create_tween()
	_step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


static func _step(tw: Tween, node: Object, property: String, to: Variant, token: int) -> void:
	var s := spec(token)
	tw.tween_property(node, property, to, float(s["duration"])).set_trans(int(s["trans"])).set_ease(int(s["ease"]))


## A show right after a hide must not be hidden again by the stale fade-out.
static func _cancel_fade(node: CanvasItem) -> void:
	if node.has_meta(FADE_META):
		var old := node.get_meta(FADE_META) as Tween
		if old != null and old.is_valid():
			old.kill()
		node.remove_meta(FADE_META)
