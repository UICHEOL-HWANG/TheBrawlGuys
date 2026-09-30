class_name ArenaShot
extends Node3D
## One arena under the match camera for evidence captures (Phase 4 T6): a MatchStage on the given
## arena, a World of bots and the CameraRig framing it exactly like a match (GD-CAM-01). The
## capture script fast-forwards the sim, pins fighters onto hazards and steps frames. No HUD, no
## Analytics autoload needed (works under `godot -s`).

var world: World
var config: GameConfig
var _stage: MatchStage
var _camera: CameraRig
var _bots: Array[BotController] = []
var _prev: Dictionary = {}
var _curr: Dictionary = {}
## fighter id -> position to hold it at every tick (hazard staging).
var _pins: Dictionary = {}


func setup(p_config: GameConfig, arena_id: String, players: int, p_seed: int) -> void:
	config = p_config
	_stage = MatchStage.new()
	add_child(_stage)
	_stage.setup(config, p_seed, players, arena_id)
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(config)
	world = World.new(config, p_seed, players, ArenaCatalog.build(arena_id, config))
	for i: int in players:
		_bots.append(BotController.new(i, config))
	_curr = world.state_view()
	_prev = _curr


## Runs the sim without drawing (bots play, pins hold).
func fast_forward(ticks: int) -> void:
	for i: int in ticks:
		_tick()


## One sim tick drawn as one frame at 60 fps, the camera easing toward the fight.
func step_frame() -> void:
	var events := _tick()
	var dt := 1.0 / 60.0
	_stage.draw(_prev, _curr, 1.0, dt)
	_stage.on_events(events)
	_camera.follow(CameraFraming.match_targets(_curr, config), dt)


func pin(fighter_id: int, at: Vector3) -> void:
	_pins[fighter_id] = at


func unpin(fighter_id: int) -> void:
	_pins.erase(fighter_id)


func stage() -> MatchStage:
	return _stage


func _tick() -> Array:
	var inputs: Array[InputFrame] = []
	for b: BotController in _bots:
		inputs.append(b.sample(_curr))
	for id: int in _pins:
		var f := world.fighters[id]
		f.pos = _pins[id]
		f.vel = Vector3.ZERO
	world.tick(inputs)
	_prev = _curr
	_curr = world.state_view()
	return _curr["events"]
