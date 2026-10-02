class_name WaitingRoomLayout
extends RefCounted
## Node building for the online waiting room (design.md DS-LAY-03 대기실): the room code header
## (caption, the code in display_l, 복사), a 2×2 grid of slot cells (PlayerSlot DS-CMP-10 over a
## ConnectionBadge DS-CMP-13) and a Panel column of compact controls. Containers and DS tokens
## only, so the screen follows UI scaling on phones.

const TITLE_TEXT := "대기실"
const GRID_COLUMNS := 2
## Control buttons are one step shorter than menu buttons; on short screens (a phone in landscape,
## logical height under SHORT_HEIGHT) one step shorter again, with tighter gaps, so the whole column
## (start and leave included) stays on screen.
const CONTROL_HEIGHT := DS.S8
const SHORT_CONTROL_HEIGHT := DS.S7
const SHORT_HEIGHT := 800.0
## 복사 only needs a short button (a menu-wide one pushed the header past narrow phones).
const COPY_WIDTH := DS.S8 * 3
## Panel width (a control button plus the panel's s6 padding) and the gap beside it.
const PANEL_WIDTH := DS.BUTTON_MIN_WIDTH + DS.S6 * 2
const ROW_GAP := DS.S6
const GRID_GAP := DS.S4


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
	copy.ready.connect(func() -> void: copy.custom_minimum_size.x = COPY_WIDTH)
	row.add_child(copy)
	return {"root": row, "code": code, "copy": copy}


## Slot columns that fit beside the panel: 2 (2×2) when the width allows, else 1 (a narrow
## phone such as an iPhone SE stacks the four slots).
static func columns_for(viewport: Viewport) -> int:
	var free := viewport.get_visible_rect().size.x - _margin(viewport) * 2 - PANEL_WIDTH - ROW_GAP
	return GRID_COLUMNS if free >= PlayerSlot.MIN_WIDTH * GRID_COLUMNS + GRID_GAP else 1


## count slot cells in `columns` columns: [{"slot": PlayerSlot, "conn": ConnectionBadge}].
static func slot_grid(parent: Control, count: int, columns: int = GRID_COLUMNS) -> Array[Dictionary]:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
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
	b.ready.connect(func() -> void:
		b.custom_minimum_size.y = SHORT_CONTROL_HEIGHT if is_short(b.get_viewport()) else CONTROL_HEIGHT)
	return b


static func _margin(viewport: Viewport) -> int:
	return DS.S4 if is_short(viewport) else DS.S6


static func is_short(viewport: Viewport) -> bool:
	return viewport != null and viewport.get_visible_rect().size.y < SHORT_HEIGHT


static func caption(text: String) -> Label:
	var l := ArenaSelectLayout.hint_label(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = DS.BUTTON_MIN_WIDTH
	l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	return l


## The screen body: the title on top (left out on short screens, where the room code header
## names the screen), then the room code header over the slot grid on the left and the control
## panel on the right, level with the header. Returns {"slots": Container, "controls": Container}.
static func body(root: Control, head: Control) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var short := is_short(root.get_viewport())  # a phone in landscape: tighter all round
	for side: String in ["top", "left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, _margin(root.get_viewport()))
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S4 if short else DS.S5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	if not short:
		col.add_child(LoginLayout.title_label(TITLE_TEXT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", DS.S5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	left.add_child(head)
	var slots := VBoxContainer.new()
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(slots)
	var panel := UiPanel.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", DS.S4)  # room between buttons on every screen
	panel.add_child(controls)
	return {"slots": slots, "controls": controls}


## Enables / disables a menu button, keeping its focus ring (no-op before it is ready).
static func set_enabled(b: UiMenuButton, on: bool) -> void:
	if b == null or not b.is_node_ready():
		return
	if not on:
		b.set_state(UiMenuButton.State.DISABLED)
	elif b.state() == UiMenuButton.State.DISABLED:
		b.set_state(UiMenuButton.State.FOCUS if b.has_focus() else UiMenuButton.State.IDLE)
