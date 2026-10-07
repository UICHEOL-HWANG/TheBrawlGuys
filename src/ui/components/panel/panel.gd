class_name UiPanel
extends PanelContainer
## Menu and settings container (design.md DS-CMP-07 v2): a comic sticker card — dim surface in
## the deep-teal outline with a thick bottom edge, radius_l corners and an s4 inner margin. One state (DEFAULT); named UiPanel because Godot already has
## a Panel class.

enum State { DEFAULT }

var _state: int = State.DEFAULT


func _ready() -> void:
	var sb := Sticker.box(DS.UI_SURFACE_DIM, DS.RADIUS_L, Sticker.DEPTH)
	sb.set_content_margin_all(DS.S4)
	sb.content_margin_bottom = DS.S4 + Sticker.DEPTH
	add_theme_stylebox_override("panel", sb)


func set_state(s: int) -> void:
	_state = s


func state() -> int:
	return _state


func set_preview() -> void:
	var l := Label.new()
	l.text = "패널 — 메뉴·설정 컨테이너"
	add_child(l)
