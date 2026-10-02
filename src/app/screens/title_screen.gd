class_name TitleScreen
extends Control
## Title / mode select (platform B1, design.md DS-LAY-03): the logo on top and, in the lower
## third, a Panel of MenuButtons (the backdrop fight stays visible in between) — 봇 대전 and 로컬 2인
## (PRD-LOCAL-01, one keyboard and/or pads; off on touch-only mobile) and 온라인 (Phase 6,
## OnlineFlow) are live — plus a small 로그아웃 in the top-right corner and, under the modes, a
## secondary 튜토리얼 다시 보기 (Phase 5 T11). Under the logo, "브롤왕님, 반가워요" once the player
## has a nickname (it follows ProfileStore.changed, e.g. right after onboarding), with a small
## "변경" link next to it ("닉네임 정하기" alone without one) that asks for the nickname screen.

signal mode_chosen(mode: String)
signal logout_requested
signal tutorial_requested
signal nickname_edit_requested

## [mode, label, enabled]
const MODES: Array[Array] = [
	[MatchSetup.MODE_BOT, "봇 대전", true],
	[MatchSetup.MODE_LOCAL_2P, "로컬 2인", true],
	[MatchSetup.MODE_ONLINE, "온라인", true],
]
## Local 2-player needs a keyboard or pads: touch-only mobile shows it disabled with this label.
const LOCAL_2P_MOBILE_TEXT := "로컬 2인 · 데스크톱 전용"
const LOGO_TEXT := LoginText.TITLE
const LOGOUT_TEXT := "로그아웃"
const TUTORIAL_TEXT := "튜토리얼 다시 보기"
const GREETING_TEXT := "%s님, 반가워요"
const CHANGE_TEXT := "변경"
const SET_TEXT := "닉네임 정하기"
const PANEL_POP_FROM := 0.9
const BACKDROP_FOCUS := Vector2(0.0, 0.18)

var _buttons: Dictionary = {}
var _logout: UiMenuButton
var _tutorial: UiMenuButton
var _panel: UiPanel
var _greeting: Label
var _greeting_gap: Control
var _nickname_link: LinkButton
## The player's profile (null = no greeting); the greeting follows its changes.
var profile: ProfileStore = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var logo := LoginLayout.title_label(LOGO_TEXT)
	logo.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_XL)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = UiPanel.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_greeting = LoginLayout.caption(false)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_OFF  # one line beside its link (a wrapping label in a row has no width)
	_greeting_gap = _gap(DS.S2)
	_nickname_link = LoginLayout.link()
	_nickname_link.pressed.connect(func() -> void: nickname_edit_requested.emit())
	var greeting_row := HBoxContainer.new()
	greeting_row.alignment = BoxContainer.ALIGNMENT_CENTER
	greeting_row.add_theme_constant_override("separation", DS.S2)
	greeting_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greeting_row.add_child(_greeting)
	greeting_row.add_child(_nickname_link)
	_refresh_greeting()
	if profile != null:
		profile.changed.connect(_refresh_greeting)
	for c: Control in [_gap(DS.S6), logo, _greeting_gap, greeting_row, fill, _panel, _gap(DS.S7)]:
		col.add_child(c)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", DS.S4)
	_panel.add_child(list)
	for m: Array in MODES:
		var mode := String(m[0])
		var mobile_2p := mode == MatchSetup.MODE_LOCAL_2P and PlatformEnv.kind() == "mobile"
		list.add_child(_mode_button(mode, LOCAL_2P_MOBILE_TEXT if mobile_2p else String(m[1]),
				bool(m[2]) and not mobile_2p))
	_tutorial = UiMenuButton.new()
	_tutorial.text = TUTORIAL_TEXT
	_tutorial.kind = UiMenuButton.Kind.SECONDARY
	_tutorial.pressed.connect(func() -> void: tutorial_requested.emit())
	list.add_child(_tutorial)
	_add_logout()
	(_buttons[MatchSetup.MODE_BOT] as Control).grab_focus.call_deferred()
	UiMotion.pop_in.call_deferred(_panel, PANEL_POP_FROM)


func nickname_link() -> LinkButton:
	return _nickname_link


func greeting_text() -> String:
	return _greeting.text if _greeting.visible else ""


func _refresh_greeting() -> void:
	var nick := profile.nickname() if profile != null else ""
	_greeting.text = GREETING_TEXT % nick
	_greeting.visible = not nick.is_empty()
	_nickname_link.text = CHANGE_TEXT if _greeting.visible else SET_TEXT


func mode_button(mode: String) -> UiMenuButton:
	return _buttons.get(mode) as UiMenuButton


func tutorial_button() -> UiMenuButton:
	return _tutorial


func logout_button() -> UiMenuButton:
	return _logout


## Logo on top, mode panel in the lower third: the backdrop fight plays in between.
func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


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
