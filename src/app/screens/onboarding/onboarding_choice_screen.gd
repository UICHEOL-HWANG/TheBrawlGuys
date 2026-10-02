class_name OnboardingChoiceScreen
extends Control
## Onboarding step 4 (design.md DS-LAY-03 온보딩): how to begin — 튜토리얼부터 (primary, focused) or
## 바로 봇전, each with a caption, and a note that the tutorial stays on the title. ↑/↓ or Tab move,
## Enter picks, Esc or 뒤로 goes back to the character pick.

signal chosen(choice: String)
signal cancelled

const CHOICE_TUTORIAL := "tutorial"
const CHOICE_BOT := "bot"
const TITLE_TEXT := "어떻게 시작할까요?"
const TUTORIAL_TEXT := "튜토리얼부터"
const TUTORIAL_CAPTION := "조작을 하나씩 배워요 · 약 3분"
const BOT_TEXT := "바로 봇전"
const BOT_CAPTION := "고른 캐릭터로 봇과 한 판"
const NOTE_TEXT := "튜토리얼은 타이틀에서 다시 볼 수 있어요"
const HINT_TEXT := "↑ ↓ 고르기 · Enter 확정 · Esc 뒤로"

var _tutorial: UiMenuButton
var _bot: UiMenuButton
var _back: UiMenuButton
var _done: bool = false


func _ready() -> void:
	_tutorial = OnboardingLayout.button(TUTORIAL_TEXT, true)
	_tutorial.pressed.connect(choose.bind(CHOICE_TUTORIAL))
	_bot = OnboardingLayout.button(BOT_TEXT, false)
	_bot.pressed.connect(choose.bind(CHOICE_BOT))
	_back = ArenaSelectLayout.back_button(OnboardingLayout.BACK_TEXT)
	_back.pressed.connect(back)
	var groups: Array[Control] = [
		OnboardingLayout.group([_tutorial, OnboardingLayout.caption(TUTORIAL_CAPTION)]),
		OnboardingLayout.group([_bot, OnboardingLayout.caption(BOT_CAPTION)]),
		OnboardingLayout.caption(NOTE_TEXT),
	]
	OnboardingLayout.build(self, TITLE_TEXT, groups, _back, HINT_TEXT)
	_tutorial.focus_neighbor_bottom = _tutorial.get_path_to(_bot)
	_bot.focus_neighbor_top = _bot.get_path_to(_tutorial)
	call_deferred("_focus_first")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and ArenaSelectScreen._is_press(event, "ui_cancel", [KEY_ESCAPE, KEY_X]):
		back()
		get_viewport().set_input_as_handled()


func choose(choice: String) -> void:
	if not _done:
		_done = true
		chosen.emit(choice)


func back() -> void:
	if not _done:
		_done = true
		cancelled.emit()


func tutorial_button() -> UiMenuButton:
	return _tutorial


func bot_button() -> UiMenuButton:
	return _bot


func back_button() -> UiMenuButton:
	return _back


func backdrop_focus() -> Vector2:
	return OnboardingLayout.BACKDROP_FOCUS


## Deferred on the screen itself (dropped if it is freed); skipped once it has left the tree.
func _focus_first() -> void:
	if _tutorial.is_inside_tree():
		_tutorial.grab_focus()
