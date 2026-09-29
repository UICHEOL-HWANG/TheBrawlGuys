extends GutTest
## Touch layouts (design.md DS-LAY-01, context E9): every variant keeps all four buttons inside
## the safe area without overlap, with attack the largest and bottom-right-most.

const SIZES := {"attack": 170.0, "jump": 130.0, "guard": 116.0, "grab": 116.0}
const GAP := 24.0
const MARGIN := 64.0
const SCREENS: Array[Rect2] = [
	Rect2(0, 0, 1920, 1080), Rect2(0, 0, 1280, 720), Rect2(96, 0, 2208, 1032),
]


func _check(variant: int, safe: Rect2) -> void:
	var c := TouchLayout.centers(variant, safe, SIZES, GAP, MARGIN)
	for name: String in TouchLayout.BUTTONS:
		assert_true(c.has(name), "%s placed" % name)
		var r: float = SIZES[name] * 0.5
		var box := Rect2(c[name] - Vector2(r, r), Vector2(r, r) * 2.0)
		assert_true(safe.encloses(box), "variant %d: %s inside %s" % [variant, name, safe])
	for i: int in TouchLayout.BUTTONS.size():
		for j: int in range(i + 1, TouchLayout.BUTTONS.size()):
			var a: String = TouchLayout.BUTTONS[i]
			var b: String = TouchLayout.BUTTONS[j]
			var need: float = (SIZES[a] + SIZES[b]) * 0.5
			assert_gte((c[a] as Vector2).distance_to(c[b]), need, "variant %d: %s/%s overlap" % [variant, a, b])
	var attack: Vector2 = c["attack"]
	assert_gte(attack.x, (c["guard"] as Vector2).x, "attack sits on the thumb side")


func test_all_variants_fit_every_screen() -> void:
	for variant: int in [TouchLayout.Variant.ARC, TouchLayout.Variant.DIAMOND, TouchLayout.Variant.GRID]:
		for safe: Rect2 in SCREENS:
			_check(variant, safe)


func test_arc_puts_attack_in_the_corner() -> void:
	var safe := Rect2(0, 0, 1920, 1080)
	var c := TouchLayout.centers(TouchLayout.Variant.ARC, safe, SIZES, GAP, MARGIN)
	assert_eq(c["attack"], safe.end - Vector2(MARGIN + 85.0, MARGIN + 85.0))


func test_unknown_variant_falls_back_to_arc() -> void:
	var safe := Rect2(0, 0, 1920, 1080)
	assert_eq(TouchLayout.centers(9, safe, SIZES, GAP, MARGIN), TouchLayout.centers(TouchLayout.Variant.ARC, safe, SIZES, GAP, MARGIN))
