extends GutTest
## Onboarding screens (design.md DS-LAY-03 온보딩): 환영 → 닉네임 → (캐릭터) → 시작 방식. Signals,
## keys, nickname validation and the async prefill.


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)


func test_welcome_starts_on_the_button_and_on_enter() -> void:
	var s := WelcomeScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.start_button().pressed.emit()
	assert_signal_emit_count(s, "started", 1)
	var again := WelcomeScreen.new()
	add_child_autofree(again)
	watch_signals(again)
	await wait_process_frames(2)
	_key(KEY_ENTER)
	await wait_process_frames(2)
	assert_signal_emitted(again, "started")


func test_nickname_submits_the_cleaned_name() -> void:
	var s := NicknameScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.field().text = "  브롤   왕 "
	s.submit()
	assert_signal_emitted_with_parameters(s, "submitted", ["브롤 왕"])


func test_an_invalid_nickname_shows_why_and_stays() -> void:
	var s := NicknameScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.field().text = "a"
	s.submit()
	assert_signal_not_emitted(s, "submitted")
	assert_eq(s.helper_text(), Nickname.TOO_SHORT)
	assert_eq(s.field().state(), UiTextField.State.ERROR)
	s.field().text = "ab"
	s.field().text_changed.emit("ab")
	assert_eq(s.helper_text(), NicknameScreen.HELPER_TEXT, "typing clears the error")


func test_prefill_fills_an_untouched_field_only() -> void:
	var s := NicknameScreen.new()
	add_child_autofree(s)
	s.set_prefill("Kim Minsu")
	assert_eq(s.field().text, "Kim Minsu")
	assert_true(s.is_prefilled())
	var typed := NicknameScreen.new()
	add_child_autofree(typed)
	typed.field().text = "내 이름"
	typed.field().text_changed.emit("내 이름")
	typed.set_prefill("Kim Minsu")
	assert_eq(typed.field().text, "내 이름", "a late account name never overwrites typing")


func test_nickname_escape_goes_back() -> void:
	var s := NicknameScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	await wait_process_frames(2)
	_key(KEY_ESCAPE)
	await wait_process_frames(2)
	assert_signal_emitted(s, "cancelled")


func test_choice_emits_tutorial_or_bot() -> void:
	var s := OnboardingChoiceScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	await wait_process_frames(2)
	assert_true(s.tutorial_button().has_focus(), "the tutorial is the suggested start")
	s.bot_button().pressed.emit()
	assert_signal_emitted_with_parameters(s, "chosen", [OnboardingChoiceScreen.CHOICE_BOT])
	var t := OnboardingChoiceScreen.new()
	add_child_autofree(t)
	watch_signals(t)
	t.tutorial_button().pressed.emit()
	assert_signal_emitted_with_parameters(t, "chosen", [OnboardingChoiceScreen.CHOICE_TUTORIAL])


func test_choice_back_button_and_escape() -> void:
	var s := OnboardingChoiceScreen.new()
	add_child_autofree(s)
	watch_signals(s)
	s.back_button().pressed.emit()
	assert_signal_emit_count(s, "cancelled", 1)
