class_name UiPanel
extends PanelContainer
## Menu and settings container (design.md DS-CMP-07): cream surface, radius_l corners, soft
## shadow and an s6 inner margin. One state (DEFAULT); named UiPanel because Godot already has
## a Panel class.

enum State { DEFAULT }

var _state: int = State.DEFAULT


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE
	sb.set_corner_radius_all(DS.RADIUS_L)
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = DS.SHADOW_SOFT_OFFSET
	sb.shadow_size = DS.SHADOW_SOFT_SIZE
	sb.set_content_margin_all(DS.S6)
	add_theme_stylebox_override("panel", sb)


func set_state(s: int) -> void:
	_state = s


func state() -> int:
	return _state


func set_preview() -> void:
	var l := Label.new()
	l.text = "패널 — 메뉴·설정 컨테이너"
	add_child(l)
