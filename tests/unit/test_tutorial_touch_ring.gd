extends GutTest
## The touch tutorial rings the on-screen button a mission asks for (polish-pass 5); split from
## test_tutorial_ui.gd, same scene fixture.

const Cases := preload("res://tests/unit/support/tutorial_cases.gd")
const BAR := preload("res://src/ui/components/key_hint_bar/key_hint_bar.tscn")
const PATH := "user://test_tutorial_touch_ring.cfg"

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


func _meet(scene: Node) -> void:
	var d: TutorialDirector = scene.call("director")
	var c := Cases.met(d.flow.goal())
	d.flow.on_tick(c["prev"], c["curr"], c["events"], c["input"], 0, d.world().config)


func _targets(touch: TouchInput) -> Array:
	var lit: Array = []
	for name: String in TouchLayout.BUTTONS:
		if (touch.buttons()[name] as TouchButton).is_target():
			lit.append(name)
	return lit


func test_touch_rings_the_button_the_mission_asks_for() -> void:
	var scene := _scene()
	await wait_process_frames(2)
	var touch := scene.get("_touch") as TouchInput
	_meet(scene)  # move
	(scene.call("director") as TutorialDirector).flow.advance()
	await wait_process_frames(2)
	assert_eq(_targets(touch), [], "keyboard play: the touch buttons stay as they are")
	touch.visible = true
	await wait_process_frames(2)
	assert_eq(_targets(touch), ["jump"])
	assert_true((touch.buttons()["jump"] as TouchButton).target_ring().is_pulsing())


func test_reduce_motion_keeps_the_touch_ring_still() -> void:
	SettingsStore.new(PATH).set_value(SpecialCutInDirector.SETTINGS_SECTION, SpecialCutInDirector.SETTINGS_KEY, true)
	var scene := _scene(SettingsStore.new(PATH))
	await wait_process_frames(2)
	var touch := scene.get("_touch") as TouchInput
	touch.visible = true
	_meet(scene)
	(scene.call("director") as TutorialDirector).flow.advance()
	await wait_process_frames(2)
	var jump := touch.buttons()["jump"] as TouchButton
	assert_true(jump.is_target())
	assert_false(jump.target_ring().is_pulsing(), "a still ring")
