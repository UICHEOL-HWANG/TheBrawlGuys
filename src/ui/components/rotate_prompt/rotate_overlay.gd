class_name RotateOverlay
extends CanvasLayer
## Rotate prompt (design.md DS-LAY-04): a touch device held in portrait (mobile web cannot lock
## orientation) gets a full-screen haze with a cream Panel — the turning RotateIcon, "가로로
## 돌려주세요" and a hint — above everything. While shown it swallows all input so nothing
## underneath reacts; the first tap asks the browser for fullscreen + landscape lock
## (DisplayProbe.request_landscape, failures ignored). Native builds are landscape-locked.

signal tapped

const LAYER := 128
const TITLE_TEXT := "가로로 돌려주세요"
const HINT_TEXT := "가로 화면에서 플레이할 수 있어요. 화면을 탭하면 전체 화면으로 바꿔 볼게요."
const HINT_WIDTH := DS.LOGIN_CARD_WIDTH

var _active: bool = false
var _asked: bool = false
var _icon: RotateIcon
var _spin: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	visible = on
	_asked = false
	if _spin != null:
		_spin.kill()
		_spin = null
	_icon.tilt = 0.0
	if on and is_inside_tree():
		_spin = _icon.play()


func is_active() -> bool:
	return _active


## True while the prompt is up: every event stops here.
func blocks(_event: InputEvent) -> bool:
	return _active


func _input(event: InputEvent) -> void:
	if not blocks(event):
		return
	get_viewport().set_input_as_handled()
	var tap := (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if tap and not _asked:
		_asked = true
		DisplayProbe.request_landscape()
		tapped.emit()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = DS.HAZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := UiPanel.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S5)
	panel.add_child(col)
	_icon = RotateIcon.new()
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_icon)
	col.add_child(_label(TITLE_TEXT, DS.FONT_DISPLAY_PATH, DS.SIZE_DISPLAY_L, DS.UI_TEXT))
	var hint := _label(HINT_TEXT, DS.FONT_CAPTION_PATH, DS.SIZE_BODY, DS.UI_TEXT_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = HINT_WIDTH
	col.add_child(hint)


func _label(text: String, font_path: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
