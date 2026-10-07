class_name UiPanel
extends PanelContainer
## Menu and settings container (design.md DS-CMP-07 v2): a flat dim card, radius_l corners and an
## s4 inner margin — no outline, so only the sticker keys inside it draw lines. One state (DEFAULT); named UiPanel because Godot already has
## a Panel class.

enum State { DEFAULT }

var _state: int = State.DEFAULT


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE_DIM
	sb.set_corner_radius_all(DS.RADIUS_L)
	sb.set_content_margin_all(DS.S4)
	add_theme_stylebox_override("panel", sb)


func set_state(s: int) -> void:
	_state = s


func state() -> int:
	return _state


func set_preview() -> void:
	var l := Label.new()
	l.text = "패널 — 메뉴·설정 컨테이너"
	add_child(l)
