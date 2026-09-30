class_name TutorialDirector
extends RefCounted
## Runs one tutorial over a World (Phase 5 T11): stages the practice arena (TutorialStaging),
## drives the dummy slot (TutorialDummy) and feeds every tick's views, events and the player's
## input to the TutorialFlow. Engine-free so tests can play it tick by tick with scripted input;
## the match scene only wires it to its loop and to the overlay.

const PLAYER_SLOT := 0
const DUMMY_SLOT := 1

var flow: TutorialFlow

var _config: GameConfig
var _world: World = null
var _dummy: TutorialDummy
var _prev_view: Dictionary = {}


func _init(config: GameConfig, p_flow: TutorialFlow) -> void:
	_config = config
	flow = p_flow
	_dummy = TutorialDummy.new(DUMMY_SLOT, PLAYER_SLOT, config)
	flow.goal_changed.connect(func(_step: String, _goal: String) -> void:
		if _world != null:
			TutorialStaging.enter(_world, DUMMY_SLOT))


## A 2-slot practice match: the player (a character with a special) against a classic dummy.
static func match_setup(player_character: String) -> MatchSetup:
	var setup := MatchSetup.vs_bots(2)
	setup.set_characters({PLAYER_SLOT: player_character, DUMMY_SLOT: CharacterData.DEFAULT})
	return setup


func begin(world: World, input_device: String = "") -> void:
	_world = world
	TutorialStaging.begin(world)
	_prev_view = world.state_view()
	flow.start(input_device)
	_maintain()


func world() -> World:
	return _world


## The dummy's input for the coming tick (it only fights during the guard mission).
func dummy_input(view: Dictionary) -> InputFrame:
	var guarding := flow.phase() == TutorialFlow.Phase.RUNNING and flow.goal() == TutorialSteps.G_GUARD
	return _dummy.sample(view, guarding)


## After World.tick(): view = its state_view(), input = what the player sent that tick.
func after_tick(view: Dictionary, input: InputFrame) -> void:
	flow.on_tick(_prev_view, view, view.get("events", []), input, PLAYER_SLOT, _config)
	_prev_view = view
	_maintain()


## KeyHintBar cap ids to ring now (none between missions).
func keys_to_press() -> Array:
	return TutorialSteps.keys(flow.goal()) if flow.phase() == TutorialFlow.Phase.RUNNING else []


func _maintain() -> void:
	if _world != null and flow.phase() == TutorialFlow.Phase.RUNNING:
		TutorialStaging.maintain(_world, flow.goal(), PLAYER_SLOT, _config)
