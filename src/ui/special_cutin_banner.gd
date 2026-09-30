class_name SpecialCutInBanner
extends CanvasLayer
## Special cut-in band (Phase 5 T4, design.md GD-CAM-01): a full-width band in the caster's
## player color with "P2 · 회전 베기" (display_l, cream text, deep outline) between two glow
## stripes, in the lower part of the screen below the zoomed caster (who is framed at the center).
## It fades and slides in by the cut-in weight (no slide with reduce motion). Anchored to the
## viewport, so the UI scale (DS-LAY-04) sizes it on phones; it never takes input. Safe to drive
## before it enters the tree (the nodes are built on first use).

const LAYER := 3
## Band center as a share of the screen height: below the zoomed caster's feet, above the key
## hint bar; the touch buttons (a higher layer) stay on top of it.
const BAND_Y_SHARE := 0.84
const BAND_HEIGHT := DS.S8 + DS.S5
const BAND_ALPHA := 0.88
## How far (px at 1920x1080) the band travels while it slides in.
const SLIDE_PX := DS.S8 * 6
const NAMES := {
	SpecialCatalog.GROUND_SLAM: "대지 강타",
	SpecialCatalog.DASH_RUSH: "돌진 연타",
	SpecialCatalog.SPIN_SLASH: "회전 베기",
	SpecialCatalog.BIG_FIREBALL: "거대 화염구",
}

var _root: Control
var _band: ColorRect
var _label: Label


func _ready() -> void:
	_build()


func _build() -> void:
	if _root != null:
		return
	layer = LAYER
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_band = _strip(DS.P1, -BAND_HEIGHT * 0.5, BAND_HEIGHT)
	_band.anchor_top = BAND_Y_SHARE
	_band.anchor_bottom = BAND_Y_SHARE
	_root.add_child(_band)
	_band.add_child(_strip(DS.GLOW, 0.0, DS.S1))
	_band.add_child(_strip(DS.GLOW, BAND_HEIGHT - DS.S1, DS.S1))
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	_label.add_theme_color_override("font_color", DS.UI_SURFACE)
	_label.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	_label.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
	_band.add_child(_label)
	_root.visible = false


## slot < 0 or weight 0 hides it. reduced: fade only, no slide.
func show_cut(slot: int, special: String, weight: float, reduced: bool) -> void:
	_build()
	if slot < 0 or weight <= 0.0:
		_root.visible = false
		return
	_root.visible = true
	var c := PlayerStyle.color(slot)
	c.a = BAND_ALPHA
	_band.color = c
	_label.text = "%s · %s" % [PlayerStyle.label(slot), String(NAMES.get(special, ""))]
	_root.modulate.a = clampf(weight, 0.0, 1.0)
	var slide := 0.0 if reduced else -(1.0 - weight) * SLIDE_PX
	_band.offset_left = slide
	_band.offset_right = slide


func is_showing() -> bool:
	return _root != null and _root.visible


func title() -> String:
	return "" if _label == null else _label.text


func band_color() -> Color:
	_build()
	return _band.color


## A full-width strip `height` px tall whose top edge is `top` px below its anchor.
static func _strip(color: Color, top: float, height: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_right = 1.0
	r.offset_top = top
	r.offset_bottom = top + height
	return r
