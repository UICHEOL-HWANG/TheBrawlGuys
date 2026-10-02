class_name NicknameScreen
extends Control
## Onboarding step 2 (design.md DS-LAY-03 온보딩): "뭐라고 부를까요?" — a UiTextField with a helper
## line under it (the rules, or why the name does not fit in danger with the field's error ring)
## and 다음. Enter or 다음 submits a valid name (Nickname rules, cleaned); Esc or 뒤로 goes back.
## set_prefill() fills the field with the account name while the player has not typed.

signal submitted(nickname: String)
signal cancelled

const TITLE_TEXT := "뭐라고 부를까요?"
const HELPER_TEXT := "2~12자 · 경기 화면에 보여요"
const PLACEHOLDER := "닉네임"
const NEXT_TEXT := "다음"
const HINT_TEXT := "Enter 다음 · Esc 뒤로"

var _field: UiTextField
var _helper: Label
var _next: UiMenuButton
var _back: UiMenuButton
var _touched: bool = false
var _prefilled: bool = false
var _done: bool = false


func _ready() -> void:
	_field = UiTextField.new()
	_field.placeholder_text = PLACEHOLDER
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.text_changed.connect(_on_typed)
	_field.text_submitted.connect(func(_t: String) -> void: submit())
	_helper = OnboardingLayout.caption(HELPER_TEXT)
	_next = OnboardingLayout.button(NEXT_TEXT, true)
	_next.focus_mode = Control.FOCUS_NONE  # the field keeps the keyboard; Enter submits
	_next.pressed.connect(submit)
	_back = ArenaSelectLayout.back_button(OnboardingLayout.BACK_TEXT)
	_back.pressed.connect(back)
	var groups: Array[Control] = [OnboardingLayout.group([_field, _helper]), _next]
	OnboardingLayout.build(self, TITLE_TEXT, groups, _back, HINT_TEXT)
	call_deferred("_focus_first")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and ArenaSelectScreen._is_press(event, "ui_cancel", [KEY_ESCAPE]):
		back()
		get_viewport().set_input_as_handled()


## The starting name (the device's last nickname or the account name), unless the player typed.
func set_prefill(nick: String) -> void:
	if _touched or nick.is_empty():
		return
	_field.text = nick
	_field.caret_column = nick.length()
	_prefilled = true


func submit() -> void:
	if _done:
		return
	var why := Nickname.error(_field.text)
	if not why.is_empty():
		_helper.text = why
		_helper.add_theme_color_override("font_color", DS.DANGER)
		_field.set_state(UiTextField.State.ERROR)
		return
	_done = true
	submitted.emit(Nickname.clean(_field.text))


func back() -> void:
	if not _done:
		_done = true
		cancelled.emit()


## Shown again after the next step backed out: editable once more.
func reopen() -> void:
	_done = false
	call_deferred("_focus_first")


func is_prefilled() -> bool:
	return _prefilled


func field() -> UiTextField:
	return _field


func helper_text() -> String:
	return _helper.text


func back_button() -> UiMenuButton:
	return _back


func backdrop_focus() -> Vector2:
	return OnboardingLayout.BACKDROP_FOCUS


func _on_typed(_t: String) -> void:
	_touched = true
	_helper.text = HELPER_TEXT
	_helper.add_theme_color_override("font_color", DS.UI_TEXT_SOFT)


## Deferred on the screen itself (dropped if it is freed); skipped once it has left the tree.
func _focus_first() -> void:
	if _field.is_inside_tree():
		_field.grab_focus()
