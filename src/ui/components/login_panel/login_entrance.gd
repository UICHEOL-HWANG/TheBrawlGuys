class_name LoginEntrance
extends RefCounted
## LoginPanel entrance motions (design.md DS-CMP-14 🖼 candidates), all on DS-TOK-05 tokens:
## ① the card springs up from below, then the logo squishes; ② the side panel springs in from the
## left and the big logo pops in; ③ the logo drops in with a bounce, then the items stagger in.

const LOGO_POP_FROM := 0.6
const ITEM_POP_FROM := 0.8
## Stagger between items in variant 3: two fast-motion beats.
const STAGGER := DS.MOTION_FAST * 2.0


static func play(variant: int, layout: Dictionary, host: Control) -> Tween:
	var tw := UiMotion.parallel(host)
	match variant:
		LoginLayout.SIDE:
			_side(tw, layout)
		LoginLayout.LOGO_DROP:
			_logo_drop(tw, layout, host)
		_:
			_card(tw, layout, host)
	return tw


static func duration(variant: int, item_count: int) -> float:
	var spring := UiMotion.duration(UiMotion.Token.SPRING)
	var squish := UiMotion.duration(UiMotion.Token.SQUISH)
	match variant:
		LoginLayout.SIDE:
			return maxf(spring, UiMotion.duration(UiMotion.Token.BASE) + squish)
		LoginLayout.LOGO_DROP:
			return UiMotion.duration(UiMotion.Token.DROP) + STAGGER * maxi(item_count - 1, 0) + squish
	return spring + squish


static func _card(tw: Tween, layout: Dictionary, host: Control) -> void:
	var card := layout["mover"] as Control
	var logo := layout["logo"] as Control
	var rest := card.position
	card.position.y = rest.y + host.size.y * 0.5
	card.modulate.a = 0.0
	UiMotion.step(tw, card, "position", rest, UiMotion.Token.SPRING)
	UiMotion.step(tw, card, "modulate:a", 1.0, UiMotion.Token.BASE)
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2.ONE
	var squish := UiMotion.step(tw, logo, "scale", Vector2.ONE, UiMotion.Token.SQUISH)
	squish.from(DS.PRESS_SQUISH).set_delay(UiMotion.duration(UiMotion.Token.SPRING))


static func _side(tw: Tween, layout: Dictionary) -> void:
	var side := layout["mover"] as Control
	var rest := side.position
	side.position.x = -side.size.x - rest.x
	UiMotion.step(tw, side, "position", rest, UiMotion.Token.SPRING)
	_pop(tw, layout["logo"] as Control, LOGO_POP_FROM, UiMotion.duration(UiMotion.Token.BASE))


static func _logo_drop(tw: Tween, layout: Dictionary, host: Control) -> void:
	var logo := layout["logo"] as Control
	var rest := logo.position
	logo.position.y = rest.y - (logo.global_position.y - host.global_position.y) - logo.size.y
	UiMotion.step(tw, logo, "position", rest, UiMotion.Token.DROP)
	var delay := UiMotion.duration(UiMotion.Token.DROP)
	for item: Control in layout["items"]:
		_pop(tw, item, ITEM_POP_FROM, delay)
		delay += STAGGER


## Hidden now, then scales up from `from` and fades in after `delay`.
static func _pop(tw: Tween, node: Control, from: float, delay: float) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from
	node.modulate.a = 0.0
	UiMotion.step(tw, node, "scale", Vector2.ONE, UiMotion.Token.SQUISH).set_delay(delay)
	UiMotion.step(tw, node, "modulate:a", 1.0, UiMotion.Token.BASE).set_delay(delay)
