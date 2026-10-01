class_name ConnectionBadge
extends HBoxContainer
## Connection indicator (design.md DS-CMP-13 ConnectionIndicator): a round dot and a caption for
## one online peer — 연결 중 (petal_yellow) · 연결됨 + ping (grass_mid good, petal_yellow fair,
## danger poor) · 연결 실패 (danger). Hidden for bots and empty slots (state NONE).

enum State { NONE, CONNECTING, CONNECTED, FAILED }

## set_conn ids (the same strings as LobbyModel.CONN_*).
const CONNS := {"connecting": State.CONNECTING, "connected": State.CONNECTED, "failed": State.FAILED}
const TEXT := {State.CONNECTING: "연결 중", State.CONNECTED: "연결됨", State.FAILED: "연결 실패"}
const PING_FORMAT := "연결됨 · %dms"
## Round-trip times at or under GOOD_MS read good, under FAIR_MS fair, else poor.
const GOOD_MS := 120
const FAIR_MS := 250
const DOT := DS.S3

var _state: int = State.NONE
var _rtt: int = -1
var _dot: Control
var _label: Label


func _init() -> void:
	add_theme_constant_override("separation", DS.S2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot = Control.new()
	_dot.custom_minimum_size = Vector2.ONE * DOT
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void: _dot.draw_circle(_dot.size * 0.5, DOT * 0.5, color()))
	add_child(_dot)
	_label = Label.new()
	_label.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	_label.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)
	add_child(_label)
	_apply()


## conn: "connecting" | "connected" | "failed" ("" or anything else = none); rtt in ms (-1 = unknown).
func set_conn(conn: String, rtt: int = -1) -> void:
	_state = int(CONNS.get(conn, State.NONE))
	_rtt = rtt
	_apply()


func state() -> int:
	return _state


func text() -> String:
	return _label.text


func color() -> Color:
	match _state:
		State.CONNECTING:
			return DS.PETAL_YELLOW
		State.FAILED:
			return DS.DANGER
		State.CONNECTED:
			if _rtt <= GOOD_MS:
				return DS.GRASS_MID
			return DS.PETAL_YELLOW if _rtt < FAIR_MS else DS.DANGER
	return DS.UI_TEXT_SOFT


func set_preview() -> void:
	set_conn("connected", 42)


func _apply() -> void:
	visible = _state != State.NONE
	if _state == State.CONNECTED and _rtt >= 0:
		_label.text = PING_FORMAT % _rtt
	else:
		_label.text = String(TEXT.get(_state, ""))
	_dot.queue_redraw()
