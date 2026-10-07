class_name Sticker
extends RefCounted
## Comic sticker surface (design.md DS-CMP-06/07 v2): a flat fill inside a deep-teal outline
## whose bottom edge is thicker — a hard "key" edge instead of a soft blurred shadow. Menu
## buttons and panels share it so every menu box reads as one family.

## Outline width and color, and the bottom "key" edge (idle / focus lifted / pressed).
const EDGE := 3
const OUTLINE := DS.CANOPY_DEEP
const DEPTH := 6
const DEPTH_FOCUS := 9
const DEPTH_PRESSED := 2


## fill inside an EDGE outline with a `depth` px bottom edge, corner `radius`.
static func box(fill: Color, radius: int, depth: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = OUTLINE
	sb.set_border_width_all(EDGE)
	sb.border_width_bottom = EDGE + depth
	sb.set_corner_radius_all(radius)
	return sb
