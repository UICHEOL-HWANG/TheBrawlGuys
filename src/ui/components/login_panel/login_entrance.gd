class_name LoginEntrance
extends RefCounted
## LoginPanel entrance (design.md DS-CMP-14), calm on DS-TOK-05 tokens: the glass card fades in
## while rising a little with a soft scale (calm), then its contents fade and lift in one after
## another (slow, staggered by fast beats). No bounce.

const CARD_FROM_SCALE := 0.96
const CARD_RISE := DS.S7
const ITEM_RISE := DS.S3
## Contents start once the card is half in.
const ITEMS_AFTER_CARD := 0.5
const STAGGER := DS.MOTION_FAST


static func play(layout: Dictionary, host: Control) -> Tween:
	var tw := UiMotion.parallel(host)
	var card := layout["card"] as Control
	var rest := card.position
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * CARD_FROM_SCALE
	card.position.y = rest.y + CARD_RISE
	card.modulate.a = 0.0
	UiMotion.step(tw, card, "position", rest, UiMotion.Token.CALM)
	UiMotion.step(tw, card, "scale", Vector2.ONE, UiMotion.Token.CALM)
	UiMotion.step(tw, card, "modulate:a", 1.0, UiMotion.Token.CALM)
	var delay := _items_delay()
	for item: Control in layout["items"]:
		_lift(tw, item, delay)
		delay += STAGGER
	return tw


static func duration(item_count: int) -> float:
	var items_end := _items_delay() + STAGGER * maxi(item_count - 1, 0) + UiMotion.duration(UiMotion.Token.SLOW)
	return maxf(UiMotion.duration(UiMotion.Token.CALM), items_end)


static func _items_delay() -> float:
	return UiMotion.duration(UiMotion.Token.CALM) * ITEMS_AFTER_CARD


## Hidden and a little low now; fades in and lifts to its place after `delay`.
static func _lift(tw: Tween, node: Control, delay: float) -> void:
	var rest := node.position
	node.position.y = rest.y + ITEM_RISE
	node.modulate.a = 0.0
	UiMotion.step(tw, node, "position", rest, UiMotion.Token.SLOW).set_delay(delay)
	UiMotion.step(tw, node, "modulate:a", 1.0, UiMotion.Token.SLOW).set_delay(delay)
