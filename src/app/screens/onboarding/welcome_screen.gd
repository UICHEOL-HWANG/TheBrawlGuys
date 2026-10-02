class_name WelcomeScreen
extends Control
## Onboarding step 1 (design.md DS-LAY-03 온보딩): a first-time player's welcome — what the game is
## and that three quick choices follow — and 시작하기. Z / Enter / Space or a click starts. No 뒤로:
## it is the first screen after signing in.

signal started

const TITLE_TEXT := "환영해요!"
const BODY_TEXT := "치고, 던지고, 장외로 날려 보내는\n난투 게임이에요."
const CAPTION_TEXT := "시작하기 전에 세 가지만 정해요."
const START_TEXT := "시작하기"
const HINT_TEXT := "Z / Enter 시작"
const CONFIRM_KEYS: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]

var _start: UiMenuButton
var _done: bool = false


func _ready() -> void:
	_start = OnboardingLayout.button(START_TEXT, true)
	_start.pressed.connect(start)
	var groups: Array[Control] = [
		OnboardingLayout.group([OnboardingLayout.body(BODY_TEXT), OnboardingLayout.caption(CAPTION_TEXT)]),
		_start,
	]
	OnboardingLayout.build(self, TITLE_TEXT, groups, null, HINT_TEXT)
	call_deferred("_focus_first")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and ArenaSelectScreen._is_press(event, "ui_accept", CONFIRM_KEYS):
		start()
		get_viewport().set_input_as_handled()


func start() -> void:
	if _done:
		return
	_done = true
	started.emit()


## Shown again after the nickname step backed out.
func reopen() -> void:
	_done = false
	call_deferred("_focus_first")


func start_button() -> UiMenuButton:
	return _start


func backdrop_focus() -> Vector2:
	return OnboardingLayout.BACKDROP_FOCUS


## Deferred on the screen itself (dropped if it is freed); skipped once it has left the tree.
func _focus_first() -> void:
	if _start.is_inside_tree():
		_start.grab_focus()
