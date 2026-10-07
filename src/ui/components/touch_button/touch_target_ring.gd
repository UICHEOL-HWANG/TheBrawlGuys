class_name TouchTargetRing
extends Control
## The tutorial's "press this now" ring on a TouchButton (Phase 5 T11, the touch twin of the
## KeyCap target ring): a ui_accent ring on the button's rim, the same width as the highlight
## ring, so it never reaches past the edge and the layout's gaps stay as they are. It breathes —
## alpha eases between ALPHA_LOW and full on motion_slow and settles back to full — and fades out
## on motion_base when the mission moves on. Reduce motion: a still, full ring.

## Breath low point: higher than the KeyCap ring's, the ring lies on a 70% cream button.
const ALPHA_LOW := 0.5
const WIDTH := TouchButton.RING_WIDTH
const SEGMENTS := 64

## Ring alpha (0 = no ring); animated while the ring is on.
var glow: float = 0.0:
	set(v):
		glow = v
		queue_redraw()

var _on: bool = false
var _still: bool = false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	if _on and not _still:
		_tween = UiMotion.pulse(self, "glow", ALPHA_LOW, 1.0, UiMotion.Token.SLOW)


## still = reduce motion: the ring holds at full instead of breathing.
func set_active(on: bool, still: bool = false) -> void:
	if on == _on and (still == _still or not on):
		return
	_on = on
	_still = still
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if on:
		glow = 1.0
		if not still and is_inside_tree():
			_tween = UiMotion.pulse(self, "glow", ALPHA_LOW, 1.0, UiMotion.Token.SLOW)
	elif is_inside_tree():
		_tween = UiMotion.parallel(self)
		UiMotion.step(_tween, self, "glow", 0.0, UiMotion.Token.BASE)
	else:
		glow = 0.0


func is_active() -> bool:
	return _on


func is_pulsing() -> bool:
	return _on and _tween != null and _tween.is_valid()


## Radius of the ring's center line (its outer edge is the button's edge).
func radius() -> float:
	return size.x * 0.5 - WIDTH * 0.5


func _draw() -> void:
	if glow <= 0.0:
		return
	var color := DS.UI_ACCENT
	color.a = glow
	draw_arc(size * 0.5, radius(), 0.0, TAU, SEGMENTS, color, WIDTH, true)
