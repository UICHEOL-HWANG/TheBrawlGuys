class_name ResultBanner
extends PanelContainer
## Match result (design.md DS-CMP-09): "승리!" / "패배…" / "무승부" in Jua display_l with an
## elastic pop, plus a restart button. Hidden until show_result().

signal restart_requested

const POP_FROM := 0.8

var _title: Label
var _button: Button


func _ready() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S5)
	add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_title.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	col.add_child(_title)
	_button = Button.new()
	_button.text = "다시 하기"
	_button.pressed.connect(func() -> void: restart_requested.emit())
	col.add_child(_button)
	visible = false


func show_result(winner_id: int, local_id: int) -> void:
	if winner_id == Rules.DRAW:
		_title.text = "무승부"
	elif winner_id == local_id:
		_title.text = "승리!"
	else:
		_title.text = "패배…"
	visible = true
	if is_inside_tree():
		pivot_offset = size * 0.5
		scale = Vector2.ONE * POP_FROM
		create_tween().tween_property(self, "scale", Vector2.ONE, DS.MOTION_SQUISH) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_button.grab_focus()


func hide_result() -> void:
	visible = false


func title() -> String:
	return _title.text


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	show_result(0, 0)
