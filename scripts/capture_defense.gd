extends SceneTree
## Defense VFX evidence (design.md DS-VFX-10~13, DefenseFx) under the real match camera: a ground
## roll and an air dodge mid-intangible (see-through + afterimages), the guard bubble at a full
## and a low meter (both flash phases), guard-break dizzy stars and the perfect-guard ring.
## Inputs go through the sim; the sim runs one tick per frame; everything shown is render-only.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_defense.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX]
## Writes <out-dir>/defense-<shot><tag>.png per SCENES shot and prints each shot's P1/P2 screen
## positions as 0..1 fractions of the frame (for cropping a sheet).

const DT := 1.0 / 60.0
const SEED := 5
const SETTLE_FRAMES := 40
const TIMEOUT := 240
const LOW_GUARD := 25.0
const BREAK_GUARD := 3.0
## trigger: the sim event (or "start" = t 0) the shot offsets count from. Offsets are frames.
## guard_hp: P1's meter at setup (P2 in "perfect"). low-on/low-off are half a 6 Hz flash apart.
const SCENES := [
	{"name": "roll", "trigger": "dodge", "shots": [[8, "roll"]], "guard_hp": 100.0},
	{"name": "air", "trigger": "dodge", "shots": [[6, "air"]], "guard_hp": 100.0},
	{"name": "guard", "trigger": "start", "shots": [[22, "guard-full"]], "guard_hp": 100.0},
	{"name": "low", "trigger": "start", "shots": [[22, "guard-low-on"], [27, "guard-low-off"]],
		"guard_hp": LOW_GUARD},
	{"name": "break", "trigger": "guard_break", "shots": [[30, "break"]], "guard_hp": BREAK_GUARD},
	{"name": "perfect", "trigger": "perfect_guard", "shots": [[4, "perfect"], [12, "perfect-late"]],
		"guard_hp": 100.0},
]
const AIR_DODGE_AT := 14
const PERFECT_GUARD_AT := 2

var _out: String = ""
var _tag: String = ""
var _index: int = -1
var _frame: int = 0
var _trigger_frame: int = -1
var _config := GameConfig.new()
var _world: World
var _stage: MatchStage
var _camera: CameraRig
var _feel: FeelDirector
var _prev: Dictionary = {}
var _curr: Dictionary = {}


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_tag = String(args.get("tag", ""))
	if _out.is_empty():
		push_error("capture_defense: usage: -- --out-dir=/abs/dir [--tag=SUFFIX]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _world == null:
		_next()
		return
	var scene: Dictionary = SCENES[_index]
	var t := _frame - SETTLE_FRAMES
	var fired := _step(t, String(scene["name"]))
	var trigger := String(scene["trigger"])
	if _trigger_frame < 0 and (fired.has(trigger) or (trigger == "start" and t == 0)):
		_trigger_frame = _frame
	_frame += 1
	_shoot(scene)
	if _world != null and _frame > SETTLE_FRAMES + TIMEOUT:
		push_error("capture_defense: no %s in scene %s" % [trigger, scene["name"]])
		_teardown()


## Saves the shots due this frame; tears the scene down after its last one.
func _shoot(scene: Dictionary) -> void:
	if _trigger_frame < 0:
		return
	var shots: Array = scene["shots"]
	for shot: Array in shots:
		if _frame == _trigger_frame + int(shot[0]):
			_save(String(shot[1]))
	if _frame >= _trigger_frame + int(shots[-1][0]):
		_teardown()


func _next() -> void:
	_index += 1
	if _index >= SCENES.size():
		quit(0)
		return
	var scene: Dictionary = SCENES[_index]
	var perfect: bool = scene["name"] == "perfect"
	_world = World.new(_config, SEED, 2)
	_world.fighters[0].pos = Vector3.ZERO
	_world.fighters[0].facing = Vector3(1, 0, 0)
	_world.fighters[1].pos = Vector3(1.0, 0, 0) if perfect else Vector3(-2.5, 0, 0)
	_world.fighters[1].facing = Vector3(-1, 0, 0)
	_world.fighters[1 if perfect else 0].guard_hp = float(scene["guard_hp"])
	_stage = MatchStage.new()
	root.add_child(_stage)
	_stage.setup(_config, SEED, 2)
	_camera = CameraRig.new()
	root.add_child(_camera)
	_camera.setup(_config)
	_feel = FeelDirector.new()
	root.add_child(_feel)
	_feel.setup(_config, _camera)
	_curr = _world.state_view()
	_prev = _curr
	_frame = 0
	_trigger_frame = -1


## The scripted inputs for tick t (t < 0 = settling): [P1, P2].
func _inputs(t: int, scene_name: String) -> Array[InputFrame]:
	var idle := InputFrame.make(0, 0)
	match scene_name:
		"roll":
			return [InputFrame.make(1 if t >= 0 else 0, 0, false, false, false, t >= 0), idle]
		"air":
			var dodge := t >= AIR_DODGE_AT
			return [InputFrame.make(1 if dodge else 0, 0, t == 0, false, false, dodge), idle]
		"guard", "low", "break":
			return [InputFrame.make(0, 0, false, false, false, t >= 0), idle]
		"perfect":
			var guard := t >= PERFECT_GUARD_AT
			return [InputFrame.make(0, 0, false, t == 0), InputFrame.make(0, 0, false, false, false, guard)]
	return [idle, idle]


## One sim tick, then everything the match draws. Returns this tick's event types.
func _step(t: int, scene_name: String) -> Array[String]:
	_prev = _curr
	_world.tick(_inputs(t, scene_name))
	_curr = _world.state_view()
	var events: Array = _curr["events"]
	_stage.draw(_prev, _curr, 1.0, DT)
	_stage.on_events(events)
	_feel.on_events(events, _curr["fighters"])
	_camera.follow(CameraFraming.match_targets(_curr, _config), DT)
	var types: Array[String] = []
	for e: Dictionary in events:
		types.append(String(e["type"]))
	return types


## Saves the frame and prints the fighters' screen positions (mid-body) for cropping.
func _save(shot_name: String) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var view := root.get_visible_rect().size
	var spots: Array[String] = []
	for f: Dictionary in _curr["fighters"]:
		var body: Vector3 = f["pos"] + Vector3.UP * (_config.fighter_height * 0.5)
		var p := cam.unproject_position(body) / view
		spots.append("%.3f,%.3f" % [p.x, p.y])
	print("capture_defense: %s screen %s" % [shot_name, " ".join(spots)])
	CaptureArgs.save(root, "%s/defense-%s%s.png" % [_out, shot_name, _tag])


func _teardown() -> void:
	for n: Node in [_stage, _camera, _feel]:
		root.remove_child(n)
		n.free()  # at once, so the next scene's camera stays current
	_world = null
