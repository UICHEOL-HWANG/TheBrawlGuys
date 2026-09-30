class_name SelectCard
extends PanelContainer
## Selection card for arenas (Phase 4) and characters (Phase 5) — design.md DS-CMP-08: a cream
## card with a diorama thumbnail (ArenaThumb), a title, a one-line caption and gimmick icons
## (GimmickIcon). States: idle · focus (petal-yellow ring, slightly larger, also on hover) ·
## selected (ring in ring_color — the accent for arenas, the player color for characters — and
## larger) · locked (dim surface, "준비 중", cannot be pressed). A click or tap emits pressed.

signal pressed

enum State { IDLE, FOCUS, SELECTED, LOCKED }

const LOCK_TEXT := "준비 중"

## Ring of the selected state (Phase 5 passes the player color).
var ring_color: Color = DS.UI_ACCENT
var _state: int = State.IDLE
var _thumb: ArenaThumb
var _title: Label
var _caption: Label
var _icons: HBoxContainer
var _lock: Label


func _init() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_thumb = ArenaThumb.new()
	col.add_child(_thumb)
	_title = _label(DS.FONT_DISPLAY_PATH, DS.SIZE_TITLE)
	col.add_child(_title)
	_caption = _label(DS.FONT_CAPTION_PATH, DS.SIZE_CAPTION)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_caption)
	_icons = HBoxContainer.new()
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons.add_theme_constant_override("separation", DS.S2)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_icons)
	_lock = _label(DS.FONT_BODY_PATH, DS.SIZE_BODY)
	_lock.text = LOCK_TEXT
	col.add_child(_lock)


func _ready() -> void:
	custom_minimum_size.x = DS.CARD_WIDTH
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(func() -> void: _follow(State.FOCUS))
	focus_exited.connect(func() -> void: _follow(State.IDLE))
	mouse_entered.connect(func() -> void:
		if _state != State.LOCKED:
			grab_focus())
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_apply()


## Card contents: title, one-line caption, diorama data (ArenaThumb) and gimmick icon kinds.
func setup(title: String, caption: String, diorama: Dictionary, icons: Array[String]) -> void:
	_title.text = title
	_caption.text = caption
	_thumb.set_diorama(diorama)
	for c: Node in _icons.get_children():
		c.queue_free()
	for k: String in icons:
		var icon := GimmickIcon.new()
		icon.kind = k
		_icons.add_child(icon)


func set_state(s: int) -> void:
	_state = s
	_apply()


func state() -> int:
	return _state


## A click, tap or confirm key: emits pressed unless the card is locked.
func press() -> void:
	if _state != State.LOCKED:
		pressed.emit()


func title_text() -> String:
	return _title.text


func icon_kinds() -> Array[String]:
	var out: Array[String] = []
	for c: Node in _icons.get_children():
		if c is GimmickIcon and not c.is_queued_for_deletion():
			out.append((c as GimmickIcon).kind)
	return out


func thumb() -> ArenaThumb:
	return _thumb


func set_preview() -> void:
	var icons: Array[String] = ["water", "fire"]
	var diorama := {"extent": 13.0, "floors": [ArenaShape.circle(Vector3.ZERO, 10.0).to_view()],
		"zones": [ArenaShape.circle(Vector3(17, 0, 0), 8.0).to_view()],
		"gimmicks": [{"kind": "burn_zone", "pos": Vector3(-4, 0, -3.5)}]}
	setup("호숫가 캠프장", "호수 낭떠러지 · 모닥불", diorama, icons)
	set_state(State.FOCUS)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		press()
		accept_event()


## Focus / hover changes never override selected or locked.
func _follow(s: int) -> void:
	if _state == State.SELECTED or _state == State.LOCKED:
		return
	set_state(s)


func _apply() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(DS.RADIUS_L)
	box.set_content_margin_all(DS.S5)
	box.bg_color = DS.UI_SURFACE_DIM if _state == State.LOCKED else DS.UI_SURFACE
	box.shadow_color = DS.UI_SHADOW
	box.shadow_offset = DS.SHADOW_SOFT_OFFSET
	box.shadow_size = DS.SHADOW_SOFT_SIZE
	if _state == State.FOCUS or _state == State.SELECTED:
		box.border_color = DS.PETAL_YELLOW if _state == State.FOCUS else ring_color
		box.set_border_width_all(DS.STROKE_FOCUS)
	add_theme_stylebox_override("panel", box)
	var grow := {State.FOCUS: DS.CARD_FOCUS_SCALE, State.SELECTED: DS.CARD_SELECTED_SCALE}
	scale = Vector2.ONE * float(grow.get(_state, 1.0))
	var locked := _state == State.LOCKED
	_lock.visible = locked
	_thumb.self_modulate = DS.UI_SURFACE_50 if locked else DS.WHITE
	for l: Label in [_title, _caption]:
		l.add_theme_color_override("font_color", DS.UI_TEXT_SOFT if locked or l == _caption else DS.UI_TEXT)


func _label(font_path: String, font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
