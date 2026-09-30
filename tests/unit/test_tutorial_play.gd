extends GutTest
## Onboarding tutorial on a real World (Phase 5 T11): a scripted player clears every mission, so
## each goal is detected from genuine sim events; the dummy only fights in the guard mission; the
## staging never changes sim code (the practice World still ticks deterministically).

const Autopilot := preload("res://tests/unit/support/tutorial_autopilot.gd")
const CONFIG_PATH := "res://src/config/default_config.tres"
const PATH := "user://test_tutorial_play.cfg"
const MAX_TICKS_PER_STEP := 1500
const PLAYER_CHARACTER := "barbarian"

var _tracked: Array = []
var _config: GameConfig


func before_each() -> void:
	_tracked.clear()
	_config = load(CONFIG_PATH) as GameConfig
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _director() -> TutorialDirector:
	var track := func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog" % n)
		_tracked.append([n, p])
	var flow := TutorialFlow.new(track, TutorialProgress.new(SettingsStore.new(PATH)), TutorialFlow.SOURCE_REPLAY)
	return TutorialDirector.new(_config, flow)


func _world(setup: MatchSetup) -> World:
	return World.new(_config, setup.seed, setup.player_count(), setup.build_arena(_config), setup.characters())


## Plays until the current step completes (or the tick budget runs out); returns ticks used.
func _play_step(d: TutorialDirector, world: World, pilot: RefCounted) -> int:
	var index := d.flow.index()
	for t: int in MAX_TICKS_PER_STEP:
		var view := world.state_view()
		var mine: InputFrame = pilot.call("sample", view, d.flow.goal())
		var inputs: Array[InputFrame] = [mine, d.dummy_input(view)]
		world.tick(inputs)
		d.after_tick(world.state_view(), mine)
		if d.flow.phase() != TutorialFlow.Phase.RUNNING or d.flow.index() != index:
			return t + 1
	return -1


func test_a_scripted_player_clears_every_mission_on_the_real_sim() -> void:
	var setup := TutorialDirector.match_setup(PLAYER_CHARACTER)
	var world := _world(setup)
	var d := _director()
	var pilot: RefCounted = Autopilot.new()
	d.begin(world, "keyboard")
	for step: String in TutorialSteps.ORDER:
		assert_eq(d.flow.step(), step)
		var used := _play_step(d, world, pilot)
		assert_gt(used, 0, "%s cleared within %d ticks" % [step, MAX_TICKS_PER_STEP])
		if used < 0:
			return
		d.flow.advance()
	assert_true(d.flow.is_done())
	var names: Array[String] = []
	for t: Array in _tracked:
		names.append(String(t[0]))
	assert_eq(names.count("tutorial_step_completed"), TutorialSteps.count())
	assert_eq(names.back(), "tutorial_completed")


func test_the_practice_arena_never_runs_out_of_stocks_or_drops_boxes() -> void:
	var world := _world(TutorialDirector.match_setup(PLAYER_CHARACTER))
	var d := _director()
	d.begin(world)
	for f: Fighter in world.fighters:
		assert_eq(f.stocks, TutorialStaging.STOCKS)
	for t: int in 1200:
		var view := world.state_view()
		var inputs: Array[InputFrame] = [InputFrame.neutral(), d.dummy_input(view)]
		world.tick(inputs)
		d.after_tick(world.state_view(), inputs[0])
	assert_eq(world.items.items.size(), 0, "no random item boxes")
	assert_false(world.match_over)


func test_the_dummy_stands_still_until_the_guard_mission() -> void:
	var world := _world(TutorialDirector.match_setup(PLAYER_CHARACTER))
	var d := _director()
	d.begin(world)
	var view := world.state_view()
	for t: int in 120:
		var f := d.dummy_input(view)
		assert_true(f.move_x == 0.0 and f.move_z == 0.0 and not f.light, "idle on the move mission")
	var dummy := TutorialDummy.new(TutorialDirector.DUMMY_SLOT, TutorialDirector.PLAYER_SLOT, _config)
	var moved := dummy.sample(view, true)
	assert_true(moved.move_x != 0.0 or moved.move_z != 0.0, "walks to the player when guarding is on")


func test_the_item_missions_keep_a_bat_available() -> void:
	var world := _world(TutorialDirector.match_setup(PLAYER_CHARACTER))
	TutorialStaging.maintain(world, TutorialSteps.G_PICKUP, 0, _config)
	assert_eq(world.items.items.size(), 1)
	assert_eq(world.items.items[0].kind, Item.Kind.BAT)
	TutorialStaging.maintain(world, TutorialSteps.G_PICKUP, 0, _config)
	assert_eq(world.items.items.size(), 1, "only one at a time")


func test_the_special_mission_fills_the_gauge() -> void:
	var world := _world(TutorialDirector.match_setup(PLAYER_CHARACTER))
	TutorialStaging.maintain(world, TutorialSteps.G_SPECIAL, 0, _config)
	assert_eq(world.fighters[0].gauge, SpecialGauge.MAX)
	assert_eq(world.fighters[0].character, PLAYER_CHARACTER)


func test_the_practice_world_stays_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var world := _world(TutorialDirector.match_setup(PLAYER_CHARACTER))
		var d := _director()
		var pilot: RefCounted = Autopilot.new()
		d.begin(world)
		for t: int in 600:
			var view := world.state_view()
			var mine: InputFrame = pilot.call("sample", view, d.flow.goal())
			var inputs: Array[InputFrame] = [mine, d.dummy_input(view)]
			world.tick(inputs)
			d.after_tick(world.state_view(), mine)
			d.flow.advance()
		hashes.append(world.state_hash())
	assert_eq(hashes[0], hashes[1])
