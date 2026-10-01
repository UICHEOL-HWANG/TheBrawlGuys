class_name WaitingRoomLayout
extends RefCounted
## Node building for the online waiting room (design.md DS-LAY-03 대기실): the room code header
## (caption, the code in display_l, 복사), a 2×2 grid of slot cells (PlayerSlot DS-CMP-10 over a
## ConnectionBadge DS-CMP-13) and a Panel column of compact controls. Containers and DS tokens
## only, so the screen follows UI scaling on phones.

const TITLE_TEXT := "대기실"
const GRID_COLUMNS := 2
## Control buttons are one step shorter than menu buttons so the column fits a phone.
const CONTROL_HEIGHT := DS.S8


## Room code header: {"root": Control, "code": Label, "copy": UiMenuButton}.
static func header(caption_text: String, copy_text: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ArenaSelectLayout.hint_label(caption_text))
	var code := Label.new()
	code.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	code.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	code.add_theme_color_override("font_color", DS.UI_TEXT)
	row.add_child(code)
	var copy := button(copy_text, UiMenuButton.Kind.SECONDARY)
	row.add_child(copy)
	return {"root": row, "code": code, "copy": copy}


## count slot cells: [{"slot": PlayerSlot, "conn": ConnectionBadge}].
static func slot_grid(parent: Control, count: int) -> Array[Dictionary]:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", DS.S4)
	grid.add_theme_constant_override("v_separation", DS.S4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	var cells: Array[Dictionary] = []
	for i: int in count:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", DS.S1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot := PlayerSlot.new()
		slot.setup(i)
		col.add_child(slot)
		var conn := ConnectionBadge.new()
		col.add_child(conn)
		grid.add_child(col)
		cells.append({"slot": slot, "conn": conn})
	return cells


## A compact control button (height CONTROL_HEIGHT).
static func button(text: String, kind: UiMenuButton.Kind) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = kind
	b.ready.connect(func() -> void: b.custom_minimum_size.y = CONTROL_HEIGHT)
	return b


static func caption(text: String) -> Label:
	var l := ArenaSelectLayout.hint_label(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = DS.BUTTON_MIN_WIDTH
	l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	return l


## The screen body: title and header on top, the slot grid and the control panel side by side.
## Returns {"slots": Container, "controls": Container}.
static func body(root: Control, head: Control) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.S6)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	col.add_child(LoginLayout.title_label(TITLE_TEXT))
	col.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	var panel := UiPanel.new()
	row.add_child(panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", DS.S3)
	panel.add_child(controls)
	return {"slots": left, "controls": controls}


## Enables / disables a menu button, keeping its focus ring (no-op before it is ready).
static func set_enabled(b: UiMenuButton, on: bool) -> void:
	if b == null or not b.is_node_ready():
		return
	if not on:
		b.set_state(UiMenuButton.State.DISABLED)
	elif b.state() == UiMenuButton.State.DISABLED:
		b.set_state(UiMenuButton.State.FOCUS if b.has_focus() else UiMenuButton.State.IDLE)
