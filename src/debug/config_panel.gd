class_name ConfigPanel
extends CanvasLayer
## Dev-only live tuning panel (design.md DS-CMP-12). Toggle: F1 or a third finger on touch.
## DS exception: default Godot styling and fixed dev sizes are allowed here.

const PANEL_WIDTH := 460.0
const NAME_WIDTH := 190.0
const VALUE_WIDTH := 70.0

var _config: GameConfig
var _root: PanelContainer
var _info: Label


func setup(config: GameConfig) -> void:
	_config = config
	layer = 100
	_root = PanelContainer.new()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_root.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(_root)

	var scroll := ScrollContainer.new()
	_root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	_info = Label.new()
	box.add_child(_info)

	var current_group := ""
	for spec: Dictionary in ConfigSchema.sliders_for(config):
		if spec["group"] != current_group:
			current_group = spec["group"]
			var header := Label.new()
			header.text = "— %s —" % current_group
			box.add_child(header)
		box.add_child(_make_row(spec))


func set_info(text: String) -> void:
	if _info:
		_info.text = text


func toggle() -> void:
	_root.visible = not _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.index == 2:
			toggle()


func _make_row(spec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = spec["name"]
	name_label.custom_minimum_size.x = NAME_WIDTH
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = spec["min"]
	slider.max_value = spec["max"]
	slider.step = spec["step"]
	slider.value = float(_config.get(spec["name"]))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.text = _format(slider.value, spec["is_int"])
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		_config.set(spec["name"], int(v) if spec["is_int"] else v)
		_config.emit_changed()
		value_label.text = _format(v, spec["is_int"]))
	return row


func _format(v: float, is_int: bool) -> String:
	return str(int(v)) if is_int else "%.3f" % v
