class_name KeyHintBar
extends HBoxContainer
## Keyboard key hints along the bottom of a match (design.md DS-CMP-16): a translucent cream
## strip (ui_surface 50%, radius_l) of KeyCaps — the arrow cluster, then one cap per action with
## a caption under it, ending with the special chord cap — plus a hide/show chip at its right
## edge. States shown · hidden (only the chip is left). Caps light from set_pressed(); the special
## cap rings from set_ready() while the gauge is full; the tutorial rings the caps to press now
## from set_highlight() (Phase 5 T11); the bar never reads input itself. Local
## 2-player bars start with a "P1"/"P2" tag (set_tag) and only the last one keeps the chip; when
## two bars do not fit side by side they go compact (tighter gaps and padding, same text sizes).

signal toggle_requested

enum State { SHOWN, HIDDEN }

const GROUP_GAP := DS.S4
const COMPACT_GROUP_GAP := DS.S2

var _panel: PanelContainer
var _row: HBoxContainer
var _chip: KeyHintChip
var _caps: Dictionary = {}
var _texts: Dictionary = {}
var _state: int = State.SHOWN
var _accent: Color = DS.UI_ACCENT
var _tag: String = ""
var _compact: bool = false
var _highlight: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", DS.S3)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", KeyHintLayout.panel_box())
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


## (Re)builds the caps from KeyHintSource.caps()-shaped entries.
func build(caps: Array[Dictionary]) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_caps.clear()
	_texts.clear()
	if not _tag.is_empty():
		_row.add_child(KeyHintLayout.tag(_tag, _accent))
	var move: Array[Dictionary] = []
	var groups: Array[Control] = []
	for c: Dictionary in caps:
		if KeyHintSource.is_move(String(c["id"])):
			move.append(c)
		else:
			groups.append(KeyHintLayout.group([_make_cap(c)], String(c["label"])))
	if not move.is_empty():
		_row.add_child(_move_group(move))
	for g: Control in groups:
		_row.add_child(g)
	set_highlight(_highlight)


## Player tag shown first ("P2"); call before build().
func set_tag(text: String) -> void:
	_tag = text


func set_compact(on: bool) -> void:
	_compact = on
	_row.add_theme_constant_override("separation", COMPACT_GROUP_GAP if on else GROUP_GAP)
	_panel.add_theme_stylebox_override("panel", KeyHintLayout.panel_box(on))


func is_compact() -> bool:
	return _compact


func set_chip_visible(on: bool) -> void:
	_chip.visible = on


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


## The ready ring (special cap while the gauge is full).
func set_ready(id: String, on: bool) -> void:
	if _caps.has(id):
		(_caps[id] as KeyCap).set_ready(on)


func cap_ready(id: String) -> bool:
	return _caps.has(id) and (_caps[id] as KeyCap).is_ready()


## Rings exactly these caps as "press this now" (tutorial, KeyCap target ring); [] clears. Ids
## the bar does not have are ignored; the set survives build().
func set_highlight(ids: Array) -> void:
	_highlight = ids.duplicate()
	for id: String in _caps:
		(_caps[id] as KeyCap).set_target(_highlight.has(id))


func highlighted() -> Array:
	var out: Array = []
	for id: String in _caps:
		if (_caps[id] as KeyCap).is_target():
			out.append(id)
	return out


func cap_text(id: String) -> String:
	return String(_texts.get(id, ""))


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


## Gallery: player-1 blue caps lighting up one after another (KeyHintPreview).
func set_preview() -> void:
	if not is_node_ready():
		await ready
	set_accent(DS.P1)
	add_child(KeyHintPreview.new(self))


func _make_cap(c: Dictionary) -> KeyCap:
	var cap := KeyCap.new()
	cap.key_text = String(c["text"])
	cap.arrow = c["arrow"]
	cap.accent = _accent
	cap.small = KeyHintSource.is_move(String(c["id"]))
	_caps[String(c["id"])] = cap
	_texts[String(c["id"])] = String(c["text"])
	return cap


## Inverted-T arrow cluster under one "이동" caption.
func _move_group(move: Array[Dictionary]) -> Control:
	var top: Array[Control] = []
	var bottom: Array[Control] = []
	for c: Dictionary in move:
		(top if c["id"] == "up" else bottom).append(_make_cap(c))
	return KeyHintLayout.group([KeyHintLayout.arrow_stack(top, bottom)], KeyHintSource.MOVE_LABEL)
