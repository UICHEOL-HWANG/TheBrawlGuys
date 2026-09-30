extends SceneTree
## Hit readability evidence (design.md DS-VFX-01 v2, DS-VFX-07~09) under the real match camera:
## a light hit, a charged heavy on a 60% target and a heavy into a guard. For each, the frame two
## ticks after the hit (inside hitstop) and ten ticks later (number rising, burst fading).
## The sim runs one tick per frame; everything shown is render-only.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_hits.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX]
## Writes <out-dir>/hit-<light|heavy|guard><tag>.png and hit-<...>-late<tag>.png. Also runs on
## builds before the comic impact (FeelDirector.on_events with one argument) for before/after.

const DT := 1.0 / 60.0
const SEED := 5
const SETTLE_FRAMES := 40
const HEAVY_HOLD := 30
const EARLY := 2
const LATE := 10
const TARGET_GAP := Vector3(1.0, 0, 0)
const SCENES := [
	{"name": "light", "damage": 0.0, "guard": false, "heavy": false},
	{"name": "heavy", "damage": 60.0, "guard": false, "heavy": true},
	{"name": "guard", "damage": 0.0, "guard": true, "heavy": true},
]

var _out: String = ""
var _tag: String = ""
var _index: int = -1
var _frame: int = 0
var _hit_frame: int = -1
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
		push_error("capture_hits: usage: -- --out-dir=/abs/dir [--tag=SUFFIX]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _world == null:
		_next()
		return
	var hit := _step(_frame - SETTLE_FRAMES)
	if hit and _hit_frame < 0:
		_hit_frame = _frame
	_frame += 1
	var shot := String(SCENES[_index]["name"])
	if _hit_frame >= 0 and _frame == _hit_frame + EARLY:
		_save("hit-%s" % shot)
	elif _hit_frame >= 0 and _frame == _hit_frame + LATE:
		_save("hit-%s-late" % shot)
		_teardown()
	elif _frame > SETTLE_FRAMES + HEAVY_HOLD + 120:
		push_error("capture_hits: no hit in scene %s" % shot)
		_teardown()


func _next() -> void:
	_index += 1
	if _index >= SCENES.size():
		quit(0)
		return
	var scene: Dictionary = SCENES[_index]
	_world = World.new(_config, SEED, 2)
	_world.fighters[0].pos = Vector3.ZERO
	_world.fighters[0].facing = Vector3(1, 0, 0)
	_world.fighters[1].pos = TARGET_GAP
	_world.fighters[1].facing = Vector3(-1, 0, 0)
	_world.fighters[1].damage = float(scene["damage"])
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
	_hit_frame = -1


## One sim tick of the scene's script (t < 0 = settling), then everything the match draws.
## Returns true when a hit or guarded hit landed this tick.
func _step(t: int) -> bool:
	var scene: Dictionary = SCENES[_index]
	var light := not bool(scene["heavy"]) and t == 0
	var heavy := bool(scene["heavy"]) and t >= 0 and t < HEAVY_HOLD
	var guard := bool(scene["guard"]) and t >= -SETTLE_FRAMES / 2
	var inputs: Array[InputFrame] = [
		InputFrame.make(0, 0, false, light, heavy),
		InputFrame.make(0, 0, false, false, false, guard),
	]
	_prev = _curr
	_world.tick(inputs)
	_curr = _world.state_view()
	var events: Array = _curr["events"]
	_stage.draw(_prev, _curr, 1.0, DT)
	_stage.on_events(events)
	var args: Array = [events, _curr["fighters"]] if _feel.has_method("active_bursts") else [events]
	_feel.callv("on_events", args)
	_camera.follow(CameraFraming.match_targets(_curr, _config), DT)
	for e: Dictionary in events:
		if String(e["type"]) in ["hit", "guard_hit"]:
			return true
	return false


func _save(shot_name: String) -> void:
	CaptureArgs.save(root, "%s/%s%s.png" % [_out, shot_name, _tag])


func _teardown() -> void:
	for n: Node in [_stage, _camera, _feel]:
		root.remove_child(n)
		n.free()  # at once, so the next scene's camera stays current
	_world = null
