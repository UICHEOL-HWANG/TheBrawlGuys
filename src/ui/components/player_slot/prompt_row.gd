class_name PromptRow
extends HBoxContainer
## One player's button prompts on a select screen (design.md DS-TOK-06): per SelectPrompts row the
## caps to press — KeyCap (small, keys and arrows) or PadGlyph (pad buttons) — then its caption.
## Hidden when the player has no prompts (touch).

const CAP_GAP := DS.S1
const ROW_GAP := DS.S4

var _rows: int = 0


func _init() -> void:
	add_theme_constant_override("separation", ROW_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## rows: SelectPrompts.for_player(...).
func set_rows(rows: Array[Dictionary]) -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_rows = rows.size()
	visible = _rows > 0
	for row: Dictionary in rows:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", CAP_GAP)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cap: Dictionary in row["caps"]:
			group.add_child(_cap(cap))
		group.add_child(_caption(String(row["label"])))
		add_child(group)


func row_count() -> int:
	return _rows


static func _cap(cap: Dictionary) -> Control:
	if cap.has("glyph"):
		var g := PadGlyph.new()
		g.glyph = String(cap["glyph"])
		return g
	var k := KeyCap.new()
	k.small = true
	k.arrow = cap.get("arrow", Vector2.ZERO)
	k.key_text = String(cap.get("text", ""))
	return k


static func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
