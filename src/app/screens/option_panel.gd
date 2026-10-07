class_name OptionPanel
extends RefCounted
## The option row of an OptionSelectScreen (design.md DS-CMP-07 Panel): a UiPanel holding one
## column per option — a MenuButton of the given width over its centered, wrapping caption in
## the soft text color. Spacing from DS tokens.


## entries: {title, caption} in display order. Each button goes into `buttons`; pressing button i
## calls on_pick(i), focusing it calls on_focus(i).
static func build(entries: Array[Dictionary], width: float, buttons: Array[UiMenuButton],
		on_pick: Callable, on_focus: Callable) -> UiPanel:
	var panel := UiPanel.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S4)
	panel.add_child(row)
	for e: Dictionary in entries:
		row.add_child(_option(e, width, buttons, on_pick, on_focus))
	return panel


static func _option(e: Dictionary, width: float, buttons: Array[UiMenuButton], on_pick: Callable,
		on_focus: Callable) -> Control:
	var i := buttons.size()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	var b := UiMenuButton.new()
	b.text = String(e["title"])
	b.ready.connect(func() -> void: b.custom_minimum_size.x = width)
	b.pressed.connect(on_pick.bind(i))
	b.focus_entered.connect(on_focus.bind(i))
	col.add_child(b)
	var caption := ArenaSelectLayout.hint_label(String(e["caption"]))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = width
	caption.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	col.add_child(caption)
	buttons.append(b)
	return col
