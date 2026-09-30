class_name TutorialOverlay
extends CanvasLayer
## The tutorial's UI layer (Phase 5 T11, design.md DS-CMP-19): the TutorialCard at the top center
## inside the safe area (s5 margin, between the HUD's corner counters) and the TutorialSkipDialog
## over everything, touch controls included (layer above TouchInput). While the dialog is open the
## tutorial is paused. 건너뛰기 on the card, Esc or a pad's Start open the dialog; Esc again resumes.

signal skip_confirmed
signal exit_requested
## The dialog closed and play goes on.
signal resumed

const LAYER := TouchInput.LAYER + 1

var _margin: MarginContainer
var _card: TutorialCard
var _dialog: TutorialSkipDialog


func _ready() -> void:
	layer = LAYER
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(row)
	_card = TutorialCard.new()
	row.add_child(_card)
	_card.skip_pressed.connect(open_dialog)
	_card.exit_pressed.connect(func() -> void: exit_requested.emit())
	_dialog = TutorialSkipDialog.new()
	add_child(_dialog)
	_dialog.resumed.connect(close_dialog)
	_dialog.confirmed.connect(func() -> void:
		_dialog.close()
		skip_confirmed.emit())
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func card() -> TutorialCard:
	return _card


func dialog() -> TutorialSkipDialog:
	return _dialog


func is_paused() -> bool:
	return _dialog != null and _dialog.is_open()


func open_dialog() -> void:
	if _card.mode() != TutorialCard.Mode.COMPLETE:
		_dialog.open()


func close_dialog() -> void:
	if _dialog.is_open():
		_dialog.close()
		resumed.emit()


## Esc / Start: open the dialog, close it again, or leave once the tutorial is complete.
func on_back() -> void:
	if _card.mode() == TutorialCard.Mode.COMPLETE:
		exit_requested.emit()
	elif is_paused():
		close_dialog()
	else:
		open_dialog()


static func is_back_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.keycode == KEY_ESCAPE)
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		return b.pressed and b.button_index == JOY_BUTTON_START
	return false


func _apply_safe_area() -> void:
	var vp := get_viewport().get_visible_rect()
	var safe := SafeArea.rect(get_viewport())
	_margin.add_theme_constant_override("margin_top", int(safe.position.y - vp.position.y) + DS.S5)
	_margin.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	_margin.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
