class_name TeamFrame
extends PanelContainer
## One team's HUD block in team 2v2 (combat-depth D, design.md DS-CMP-21, GetAmped style): a
## soft surface with a team-color frame, a "팀 1" / "팀 2" header pill in the team color and the
## team's player slots (DamageCounter + StockIcons, badges tinted the team color) side by side.
## Team 1 sits at the left edge of the HUD, team 2 at the right.

const FRAME_ALPHA_FILL := DS.UI_SURFACE_50

var _team: int = 0
var _header: Label
var _slots: HBoxContainer


func _init() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_header.add_theme_font_size_override("font_size", DS.SIZE_BODY)
	_header.add_theme_color_override("font_color", DS.UI_SURFACE)
	col.add_child(_header)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", DS.S4)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_slots)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(team: int) -> void:
	_team = team
	var c := PlayerStyle.team_color(team)
	_header.text = PlayerStyle.team_label(team)
	var pill := StyleBoxFlat.new()
	pill.bg_color = c
	pill.set_corner_radius_all(DS.RADIUS_PILL)
	pill.content_margin_left = DS.S4
	pill.content_margin_right = DS.S4
	_header.add_theme_stylebox_override("normal", pill)
	var frame := StyleBoxFlat.new()
	frame.bg_color = FRAME_ALPHA_FILL
	frame.border_color = c
	frame.set_border_width_all(DS.STROKE_FOCUS)
	frame.set_corner_radius_all(DS.RADIUS_L)
	frame.set_content_margin_all(DS.S3)
	add_theme_stylebox_override("panel", frame)


## Where the team's player slots go.
func slots() -> HBoxContainer:
	return _slots


func team() -> int:
	return _team


func header_text() -> String:
	return _header.text
