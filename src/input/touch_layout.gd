class_name TouchLayout
extends RefCounted
## Touch button placement (design.md DS-LAY-01, context E9): three candidates for the 🖼 gate.
## All keep the attack button (largest) at the bottom-right thumb rest inside the safe area.
##   ARC     jump / guard / grab on an arc around attack (left, up-left, up)
##   DIAMOND attack east, jump south, guard west, grab north
##   GRID    2x2: guard grab / jump attack

enum Variant { ARC, DIAMOND, GRID }

const BUTTONS: Array[String] = ["attack", "jump", "guard", "grab"]
## Arc angles in screen space (y down): left, up-left, up.
const ARC_DEGREES := {"jump": 180.0, "guard": 225.0, "grab": 270.0}


static func centers(variant: int, safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	match variant:
		Variant.DIAMOND:
			return _diamond(safe, sizes, gap, margin)
		Variant.GRID:
			return _grid(safe, sizes, gap, margin)
		_:
			return _arc(safe, sizes, gap, margin)


static func _r(sizes: Dictionary, name: String) -> float:
	return float(sizes[name]) * 0.5


static func _corner(safe: Rect2, sizes: Dictionary, margin: float) -> Vector2:
	var ra := _r(sizes, "attack")
	return safe.end - Vector2(margin + ra, margin + ra)


static func _arc(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var attack := _corner(safe, sizes, margin)
	var out := {"attack": attack}
	for name: String in ARC_DEGREES:
		var a := deg_to_rad(float(ARC_DEGREES[name]))
		out[name] = attack + Vector2(cos(a), sin(a)) * (_r(sizes, "attack") + _r(sizes, name) + gap)
	return out


static func _diamond(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var ra := _r(sizes, "attack")
	var side := maxf(maxf(_r(sizes, "jump"), _r(sizes, "guard")), _r(sizes, "grab"))
	var arm := (ra + side + gap) * 0.75
	var hub := Vector2(safe.end.x - margin - ra - arm, safe.end.y - margin - _r(sizes, "jump") - arm)
	return {
		"attack": hub + Vector2(arm, 0), "jump": hub + Vector2(0, arm),
		"guard": hub + Vector2(-arm, 0), "grab": hub + Vector2(0, -arm),
	}


static func _grid(safe: Rect2, sizes: Dictionary, gap: float, margin: float) -> Dictionary:
	var ra := _r(sizes, "attack")
	var attack := _corner(safe, sizes, margin)
	var jump := attack + Vector2(-(ra + _r(sizes, "jump") + gap), ra - _r(sizes, "jump"))
	var grab := attack + Vector2(0, -(ra + _r(sizes, "grab") + gap))
	return {"attack": attack, "jump": jump, "grab": grab, "guard": Vector2(jump.x, grab.y)}
