extends GutTest
## Tutorial scene UI (Phase 5 T11, design.md DS-CMP-19): the mission card follows the flow, the
## KeyHintBar rings the keys to press now, the instruction line follows the device, Esc pauses on
## the skip dialog, skipping or finishing leaves for the title.

const Cases := preload("res://tests/unit/support/tutorial_cases.gd")
const BAR := preload("res://src/ui/components/key_hint_bar/key_hint_bar.tscn")
const PATH := "user://test_tutorial_ui.cfg"

var _tracked: Array = []
var _left: int = 0


func before_each() -> void:
	InputBindings.apply()
	_tracked.clear()
	_left = 0
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _scene(settings: SettingsStore = null) -> Node:
	var track := func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	var scene := TutorialLauncher.scene(TutorialFlow.SOURCE_REPLAY, TutorialProgress.new(SettingsStore.new(PATH)),
			track, func() -> void: _left += 1)
	if settings != null:
		scene.set("settings", settings)
	add_child_autofree(scene)
	return scene


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


## Meets the current goal as if the sim had just produced it.
func _meet(scene: Node) -> void:
	var d: TutorialDirector = scene.call("director")
	var c := Cases.met(d.flow.goal())
	d.flow.on_tick(c["prev"], c["curr"], c["events"], c["input"], 0, d.world().config)


func test_the_card_opens_on_the_first_mission_and_rings_its_keys() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var card: TutorialCard = (scene.call("overlay") as TutorialOverlay).card()
	assert_eq(card.tag_text(), "튜토리얼 · 1/8")
	assert_eq(card.title_text(), TutorialSteps.title(TutorialSteps.MOVE))
	assert_string_contains(card.line_text(), "방향키로")
	var bar := (scene.call("get_hud") as Hud).key_hints().bar()
	var lit := bar.highlighted()
	lit.sort()
	assert_eq(lit, ["down", "left", "right", "up"])
	assert_eq(scene.call("get_world").fighters[0].character, "barbarian")


func test_a_cleared_mission_celebrates_then_moves_on() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var card: TutorialCard = (scene.call("overlay") as TutorialOverlay).card()
	_meet(scene)
	assert_eq(card.title_text(), TutorialCard.SUCCESS_TITLE)
	await wait_process_frames(2)
	var bar := (scene.call("get_hud") as Hud).key_hints().bar()
	assert_eq(bar.highlighted(), [], "no keys while celebrating")
	await wait_seconds(scene.get("FEEDBACK_S") + 0.3)
	assert_eq(card.title_text(), TutorialSteps.title(TutorialSteps.JUMP))
	assert_eq(card.tag_text(), "튜토리얼 · 2/8")
	assert_eq(bar.highlighted(), ["jump"])


func test_esc_pauses_on_the_skip_dialog_and_resumes() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var overlay: TutorialOverlay = scene.call("overlay")
	scene.call("_unhandled_input", _esc())
	assert_true(overlay.dialog().is_open())
	var tick: int = scene.call("get_world").tick_count
	await wait_seconds(0.2)
	assert_eq(scene.call("get_world").tick_count, tick, "the sim waits while the dialog is up")
	scene.call("_unhandled_input", _esc())
	assert_false(overlay.dialog().is_open(), "Esc again keeps playing")
	await wait_seconds(0.2)
	assert_gt(scene.call("get_world").tick_count, tick)
	overlay.card().skip_button().pressed.emit()
	overlay.dialog().resume_button().pressed.emit()
	assert_false(overlay.dialog().is_open())
	assert_eq(_left, 0)


func test_confirming_the_skip_leaves_and_tracks_it() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var overlay: TutorialOverlay = scene.call("overlay")
	overlay.open_dialog()
	overlay.dialog().confirm_button().pressed.emit()
	assert_eq(_left, 1)
	var names := _tracked.map(func(t: Array) -> String: return t[0])
	assert_eq(names, ["tutorial_started", "tutorial_skipped"], "only tutorial events, no match telemetry")


func test_finishing_shows_the_complete_card_and_its_button_leaves() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var d: TutorialDirector = scene.call("director")
	for i: int in TutorialSteps.count():
		for g: int in TutorialSteps.goals(d.flow.step()).size():
			_meet(scene)
		d.flow.advance()
	var card: TutorialCard = (scene.call("overlay") as TutorialOverlay).card()
	assert_eq(card.mode(), TutorialCard.Mode.COMPLETE)
	assert_true(card.exit_button().visible)
	assert_false(card.skip_button().visible)
	scene.call("_unhandled_input", _esc())
	assert_eq(_left, 1, "Esc leaves once it is complete")
	card.exit_button().pressed.emit()
	scene.call("_unhandled_input", _esc())
	assert_eq(_left, 1, "leaving happens once, whatever is pressed during the curtain")


func test_the_line_follows_the_device_in_hand() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var card: TutorialCard = (scene.call("overlay") as TutorialOverlay).card()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	scene.call("_input", pad)
	await wait_process_frames(2)
	assert_string_contains(card.line_text(), "왼쪽 스틱으로")
	(scene.get("_touch") as TouchInput).visible = true
	await wait_process_frames(2)
	assert_string_contains(card.line_text(), "스틱")
	assert_false(card.line_text().contains("왼쪽 스틱으로"), "touch names the on-screen stick")


func test_the_skip_button_never_takes_focus() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var card: TutorialCard = (scene.call("overlay") as TutorialOverlay).card()
	assert_eq(card.skip_button().focus_mode, Control.FOCUS_NONE, "Space jumps, it never presses 건너뛰기")


func test_the_key_bar_highlights_exactly_the_given_caps() -> void:
	var bar := BAR.instantiate() as KeyHintBar
	add_child_autofree(bar)
	bar.set_highlight(["jump", "special", "nope"])
	var lit := bar.highlighted()
	lit.sort()
	assert_eq(lit, ["jump", "special"], "unknown ids are ignored")
	bar.build(KeyHintSource.caps())
	assert_eq(bar.highlighted().size(), 2, "a rebuild keeps the highlight")
	bar.set_highlight([])
	assert_eq(bar.highlighted(), [])
