class_name TitleScreen
extends Control
## Title / mode select (platform B1, design.md DS-LAY-03): the logo over the backdrop and a Panel
## of MenuButtons — 봇 대전 is live, 로컬 2인 and 온라인 are shown disabled ("준비 중") until
## Phase 5/6 — plus a small 로그아웃 in the top-right corner.

signal mode_chosen(mode: String)
signal logout_requested

## [mode, label, enabled]
const MODES: Array[Array] = [
	[MatchSetup.MODE_BOT, "봇 대전", true],
	[MatchSetup.MODE_LOCAL_2P, "로컬 2인 · 준비 중", false],
	[MatchSetup.MODE_ONLINE, "온라인 · 준비 중", false],
]
const LOGO_TEXT := LoginPanel.TITLE_TEXT
const LOGOUT_TEXT := "로그아웃"
const PANEL_POP_FROM := 0.9

var _buttons: Dictionary = {}
var _logout: UiMenuButton
var _panel: UiPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S6)
	center.add_child(col)
	var logo := Label.new()
	logo.text = LOGO_TEXT
	LoginLayout.style_world_text(logo, DS.SIZE_DISPLAY_XL)
	col.add_child(logo)
	_panel = UiPanel.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", DS.S4)
	_panel.add_child(list)
	for m: Array in MODES:
		list.add_child(_mode_button(String(m[0]), String(m[1]), bool(m[2])))
	_add_logout()
	(_buttons[MatchSetup.MODE_BOT] as Control).grab_focus.call_deferred()
	UiMotion.pop_in.call_deferred(_panel, PANEL_POP_FROM)


func mode_button(mode: String) -> UiMenuButton:
	return _buttons.get(mode) as UiMenuButton


func logout_button() -> UiMenuButton:
	return _logout


func _mode_button(mode: String, label: String, enabled: bool) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = label
	b.kind = UiMenuButton.Kind.PRIMARY if enabled else UiMenuButton.Kind.SECONDARY
	b.pressed.connect(func() -> void: mode_chosen.emit(mode))
	_buttons[mode] = b
	if not enabled:
		b.ready.connect(func() -> void: b.set_state(UiMenuButton.State.DISABLED))
	return b


func _add_logout() -> void:
	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for side: String in ["top", "right"]:
		corner.add_theme_constant_override("margin_" + side, DS.S5)
	add_child(corner)
	_logout = UiMenuButton.new()
	_logout.text = LOGOUT_TEXT
	_logout.kind = UiMenuButton.Kind.SECONDARY
	corner.add_child(_logout)
	_logout.custom_minimum_size = Vector2(0, DS.S8)
	_logout.pressed.connect(func() -> void: logout_requested.emit())
