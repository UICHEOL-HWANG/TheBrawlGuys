class_name UiMotion
extends RefCounted
## Motion tokens (design.md DS-TOK-05) as ready-made tweens, so every UI transition uses the
## same timings: fast = press, base = panels, squish = pops and banners, slow = screens,
## spring / drop = big menu entrances (login panel).

enum Token { FAST, BASE, SQUISH, SLOW, SPRING, DROP }

const FADE_META := &"ui_motion_fade"


static func spec(token: int) -> Dictionary:
	match token:
		Token.FAST:
			return {"duration": DS.MOTION_FAST, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}
		Token.SQUISH:
			return {"duration": DS.MOTION_SQUISH, "trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT}
		Token.SLOW:
			return {"duration": DS.MOTION_SLOW, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT}
		Token.SPRING:
			return {"duration": DS.MOTION_ENTRANCE, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT}
		Token.DROP:
			return {"duration": DS.MOTION_ENTRANCE, "trans": Tween.TRANS_BOUNCE, "ease": Tween.EASE_OUT}
	return {"duration": DS.MOTION_BASE, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT}


static func duration(token: int) -> float:
	return float(spec(token)["duration"])


static func pop_in(node: Control, from_scale: float) -> Tween:
	_cancel_fade(node)
	node.visible = true
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	step(tw, node, "modulate:a", 1.0, Token.BASE)
	return tw


static func fade_in(node: CanvasItem, token: int = Token.SLOW) -> Tween:
	_cancel_fade(node)
	node.visible = true
	node.modulate.a = 0.0
	var tw := node.create_tween()
	step(tw, node, "modulate:a", 1.0, token)
	return tw


static func fade_out(node: CanvasItem) -> Tween:
	_cancel_fade(node)
	var tw := node.create_tween()
	step(tw, node, "modulate:a", 0.0, Token.BASE)
	tw.tween_callback(func() -> void: node.visible = false)
	node.set_meta(FADE_META, tw)
	return tw


static func bump(node: Control, from_scale: float) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	var tw := node.create_tween()
	step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


static func release(node: Control) -> Tween:
	var tw := node.create_tween()
	step(tw, node, "scale", Vector2.ONE, Token.SQUISH)
	return tw


## An empty parallel tween for choreographies built from step() (login entrances).
static func parallel(node: Node) -> Tween:
	return node.create_tween().set_parallel(true)


## One tokenized property step on a tween (callers add delays or run steps in parallel).
static func step(tw: Tween, node: Object, property: String, to: Variant, token: int) -> PropertyTweener:
	var s := spec(token)
	return tw.tween_property(node, property, to, float(s["duration"])).set_trans(int(s["trans"])).set_ease(int(s["ease"]))


## A show right after a hide must not be hidden again by the stale fade-out.
static func _cancel_fade(node: CanvasItem) -> void:
	if node.has_meta(FADE_META):
		var old := node.get_meta(FADE_META) as Tween
		if old != null and old.is_valid():
			old.kill()
		node.remove_meta(FADE_META)
