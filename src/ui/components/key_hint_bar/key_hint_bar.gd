class_name KeyHintBar
extends HBoxContainer
## Keyboard key hints along the bottom of a match (design.md DS-CMP-16): a translucent cream
## strip (ui_surface 50%, radius_l) of KeyCaps — the arrow cluster, then one cap per action with
## a caption under it — plus a hide/show chip at its right edge. States shown · hidden (only the
## chip is left). Caps light from set_pressed(); the bar never reads input itself.

signal toggle_requested

enum State { SHOWN, HIDDEN }

const GROUP_GAP := DS.S4
const CAP_GAP := DS.S1
## Gallery preview: seconds each key stays lit while the preview walks along the bar.
const PREVIEW_STEP_S := 0.35

var _panel: PanelContainer
var _row: HBoxContainer
var _chip: KeyHintChip
var _caps: Dictionary = {}
var _state: int = State.SHOWN
var _accent: Color = DS.UI_ACCENT
var _preview: bool = false
var _preview_s: float = 0.0
var _preview_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", DS.S3)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_box())
	add_child(_panel)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", GROUP_GAP)
	_panel.add_child(_row)
	_chip = KeyHintChip.new()
	_chip.size_flags_vertical = Control.SIZE_SHRINK_END
	_chip.pressed.connect(func() -> void: toggle_requested.emit())
	add_child(_chip)
	build(KeyHintSource.caps())
	set_process(false)  # only the gallery preview animates


## (Re)builds the caps from KeyHintSource.caps()-shaped entries.
func build(caps: Array[Dictionary]) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_caps.clear()
	var move: Array[Dictionary] = []
	for c: Dictionary in caps:
		if KeyHintSource.is_move(String(c["id"])):
			move.append(c)
		else:
			_row.add_child(_group([_make_cap(c)], String(c["label"])))
	if not move.is_empty():
		_row.add_child(_move_group(move))
		_row.move_child(_row.get_child(_row.get_child_count() - 1), 0)


func set_accent(color: Color) -> void:
	_accent = color
	for cap: KeyCap in _caps.values():
		cap.accent = color


func accent() -> Color:
	return _accent


func set_pressed(id: String, on: bool) -> void:
	if _caps.has(id):
		(_caps[id] as KeyCap).set_state(KeyCap.State.PRESSED if on else KeyCap.State.IDLE)


func cap_state(id: String) -> int:
	return (_caps[id] as KeyCap).state() if _caps.has(id) else KeyCap.State.IDLE


func cap_ids() -> Array:
	return _caps.keys()


func set_state(s: int, animate: bool = true) -> void:
	_state = s
	_chip.set_shown(s == State.SHOWN)
	if s == State.HIDDEN:
		for id: String in _caps:
			set_pressed(id, false)
	if not (animate and is_inside_tree()):
		_panel.visible = s == State.SHOWN
		_panel.modulate.a = 1.0
	elif s == State.SHOWN:
		UiMotion.fade_in(_panel, UiMotion.Token.BASE)
	else:
		UiMotion.fade_out(_panel)


func state() -> int:
	return _state


func chip() -> KeyHintChip:
	return _chip


## Gallery: player-1 blue caps lighting up one after another.
func set_preview() -> void:
	if not is_node_ready():
		await ready
	set_accent(DS.P1)
	_preview = true
	set_process(true)
	_preview_index = 0
	set_pressed(String(cap_ids()[0]), true)


func _process(delta: float) -> void:
	if not _preview:
		return
	_preview_s += delta
	if _preview_s < PREVIEW_STEP_S:
		return
	_preview_s = 0.0
	var ids := cap_ids()
	set_pressed(String(ids[_preview_index]), false)
	_preview_index = (_preview_index + 1) % ids.size()
	set_pressed(String(ids[_preview_index]), true)


func _make_cap(c: Dictionary) -> KeyCap:
	var cap := KeyCap.new()
	cap.key_text = String(c["text"])
	cap.arrow = c["arrow"]
	cap.accent = _accent
	_caps[String(c["id"])] = cap
	return cap


## Inverted-T arrow cluster: up on top, left · down · right below, one caption.
func _move_group(move: Array[Dictionary]) -> Control:
	var top := _cap_row()
	var bottom := _cap_row()
	for c: Dictionary in move:
		(top if c["id"] == "up" else bottom).add_child(_make_cap(c))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", CAP_GAP)
	stack.add_child(top)
	stack.add_child(bottom)
	return _group([stack], KeyHintSource.MOVE_LABEL)


func _cap_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CAP_GAP)
	return row


func _group(parts: Array, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", DS.S1)
	for p: Control in parts:
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(p)
	box.add_child(_caption(caption))
	return box


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	return l


func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE_50
	sb.set_corner_radius_all(DS.RADIUS_L)
	sb.content_margin_left = DS.S5
	sb.content_margin_right = DS.S5
	sb.content_margin_top = DS.S3
	sb.content_margin_bottom = DS.S2
	return sb
