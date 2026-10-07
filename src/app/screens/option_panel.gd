class_name OptionPanel
extends RefCounted
## The option row of an OptionSelectScreen (design.md DS-CMP-07 Panel): a UiPanel holding one
## column per option — a MenuButton of the given width over its centered, wrapping caption in
## the soft text color. When every option has the same caption it is shown once under the row.
## Spacing from DS tokens.


## entries: {title, caption} in display order. Each button goes into `buttons`; pressing button i
## calls on_pick(i), focusing it calls on_focus(i).
static func build(entries: Array[Dictionary], width: float, buttons: Array[UiMenuButton],
		on_pick: Callable, on_focus: Callable) -> UiPanel:
	var panel := UiPanel.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S3)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S4)
	col.add_child(row)
	var shared := _shared_caption(entries)
	for e: Dictionary in entries:
		row.add_child(_option(e, width, buttons, on_pick, on_focus, shared.is_empty()))
	if not shared.is_empty():  # the same caption under every option says it once, under the row
		col.add_child(_caption(shared, -1.0))
	return panel


## The caption every entry shares, or "" when they differ (or there is only one entry).
static func _shared_caption(entries: Array[Dictionary]) -> String:
	if entries.size() < 2:
		return ""
	var first := String(entries[0]["caption"])
	for e: Dictionary in entries:
		if String(e["caption"]) != first:
			return ""
	return first


static func _option(e: Dictionary, width: float, buttons: Array[UiMenuButton], on_pick: Callable,
		on_focus: Callable, with_caption: bool) -> Control:
	var i := buttons.size()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	var b := UiMenuButton.new()
	b.text = String(e["title"])
	b.ready.connect(func() -> void: b.custom_minimum_size.x = width)
	b.pressed.connect(on_pick.bind(i))
	b.focus_entered.connect(on_focus.bind(i))
	col.add_child(b)
	if with_caption:
		col.add_child(_caption(String(e["caption"]), width))
	buttons.append(b)
	return col


## A centered, wrapping caption in the soft text color; width < 0 = as wide as its row.
static func _caption(text: String, width: float) -> Label:
	var caption := ArenaSelectLayout.hint_label(text)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width >= 0.0:
		caption.custom_minimum_size.x = width
	caption.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	return caption
