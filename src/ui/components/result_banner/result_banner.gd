class_name ResultBanner
extends PanelContainer
## Match result (design.md DS-CMP-09): "승리!" / "패배…" / "무승부" in Jua display_l with an
## elastic pop, plus "다시 하기" and, when an app shell can take the player back, "메뉴로"
## (both DS-CMP-06 MenuButtons). Hidden until show_result(). With no single local viewer (local
## 2-player, PRD-LOCAL-01) the winner is named instead: "P2 승리!".

signal restart_requested
signal menu_requested

const POP_FROM := 0.8
const RESTART_TEXT := "다시 하기"
const MENU_TEXT := "메뉴로"
## show_result() local_id when no one human's point of view applies.
const NO_LOCAL := -1

var _title: Label
var _button: UiMenuButton
var _menu_button: UiMenuButton


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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S4)
	col.add_child(row)
	_button = _make_button(RESTART_TEXT, UiMenuButton.Kind.PRIMARY, restart_requested)
	row.add_child(_button)
	_menu_button = _make_button(MENU_TEXT, UiMenuButton.Kind.SECONDARY, menu_requested)
	_menu_button.visible = false
	row.add_child(_menu_button)
	visible = false


func show_result(winner_id: int, local_id: int) -> void:
	if winner_id == Rules.DRAW:
		_title.text = "무승부"
	elif local_id == NO_LOCAL:
		_title.text = "%s 승리!" % PlayerStyle.label(winner_id)
	elif winner_id == local_id:
		_title.text = "승리!"
	else:
		_title.text = "패배…"
	if is_inside_tree():
		UiMotion.pop_in(self, POP_FROM)
		_button.grab_focus()
	else:
		visible = true


func hide_result() -> void:
	if is_inside_tree() and visible:
		UiMotion.fade_out(self)
	else:
		visible = false


func set_menu_available(on: bool) -> void:
	_menu_button.visible = on


func title() -> String:
	return _title.text


func menu_button() -> UiMenuButton:
	return _menu_button


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	set_menu_available(true)
	show_result(0, 0)


func _make_button(text: String, kind: UiMenuButton.Kind, sig: Signal) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.kind = kind
	b.text = text
	b.pressed.connect(func() -> void: sig.emit())
	return b
