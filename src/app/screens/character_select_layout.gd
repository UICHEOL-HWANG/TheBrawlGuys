class_name CharacterSelectLayout
extends RefCounted
## Character select layout (Phase 5 T9, design.md DS-LAY-02/03/04): one centered column — title,
## the character cards, the PlayerSlot row — in a FitCenter above the footer (뒤로 bottom left,
## hint bottom right, inside the safe area; ArenaSelectLayout's footer parts). On short screens
## (phones after UI scaling) the column goes compact: shorter portraits and one-line captions,
## and anything still too tall scrolls instead of running under the footer. Text never shrinks.

## Logical heights below this use the compact column (812x375 at scale 1.6 is about 673).
const COMPACT_BELOW := 900.0
const COMPACT_THUMB_HEIGHT := DS.S8 + DS.S6
const FOOTER_RESERVE := DS.BUTTON_HEIGHT + DS.S6 * 2
const ROW_GAP := DS.S5
const COMPACT_ROW_GAP := DS.S3


## Adds the column and the footer to root; returns {fit: FitCenter, footer: MarginContainer,
## column: VBoxContainer}.
static func build(root: Control, title: String, cards: Control, slots: Control, back: Control,
		hint: Control, compact: bool) -> Dictionary:
	var fit := FitCenter.new()
	root.add_child(fit)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", COMPACT_ROW_GAP if compact else ROW_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(LoginLayout.title_label(title))
	cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cards)
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(slots)
	fit.content().add_child(column)
	var footer := MarginContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	row.add_child(hint)
	footer.add_child(row)
	root.add_child(footer)
	return {"fit": fit, "footer": footer, "column": column}


## The column's row gap for the compact (phone) or regular layout.
static func set_compact(parts: Dictionary, compact: bool) -> void:
	(parts["column"] as VBoxContainer).add_theme_constant_override("separation",
			COMPACT_ROW_GAP if compact else ROW_GAP)


## Footer in the safe area; the column stops above it.
static func apply_safe_area(parts: Dictionary, viewport: Viewport) -> void:
	var footer := parts["footer"] as MarginContainer
	ArenaSelectLayout.apply_safe_area(footer, viewport)
	var vp := viewport.get_visible_rect()
	var bottom_inset := vp.end.y - SafeArea.rect(viewport).end.y
	(parts["fit"] as FitCenter).offset_bottom = -(FOOTER_RESERVE + bottom_inset)


static func is_compact(viewport: Viewport) -> bool:
	return viewport.get_visible_rect().size.y < COMPACT_BELOW


static func thumb_height(compact: bool) -> float:
	return COMPACT_THUMB_HEIGHT if compact else DS.CARD_THUMB_HEIGHT


## "권투 스타일\n필살기 · 대지 강타", or "권투 · 대지 강타" on one line when compact.
static func caption(entry: Dictionary, compact: bool) -> String:
	if compact:
		return "%s · %s" % [entry["style_name"], entry["special_name"]]
	return String(entry["caption"])
