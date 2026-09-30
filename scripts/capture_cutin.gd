extends SceneTree
## Phase 5 T4 evidence: the special cut-in (GD-CAM-01) under the real match camera. For each
## character (slot 0, full gauge, facing a still classic fighter) X+C is pressed and the frame is
## shot mid-hold; the first character is also shot just before the press and after the camera has
## returned. The sim runs one tick per frame; the cut-in is render-only.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_cutin.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX] [--reduce-motion=1]
## Writes <out-dir>/cutin-before<tag>.png, cutin-<character><tag>.png per character and
## cutin-after<tag>.png.

const DT := 1.0 / 60.0
const SEED := 5
const SETTLE_FRAMES := 40
const FOE_OFFSET := Vector3(1.6, 0, 0.4)

var _out: String = ""
var _tag: String = ""
var _reduce: bool = false
var _index: int = -1
var _frame: int = 0
var _config := GameConfig.new()
var _world: World
var _stage: MatchStage
var _camera: CameraRig
var _director: SpecialCutInDirector
var _prev: Dictionary = {}
var _curr: Dictionary = {}


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_tag = String(args.get("tag", ""))
	_reduce = String(args.get("reduce-motion", "0")) == "1"
	if _out.is_empty():
		push_error("capture_cutin: usage: -- --out-dir=/abs/dir [--tag=SUFFIX] [--reduce-motion=1]")
		quit(1)
		return
	process_frame.connect(_on_frame)


## Mid-hold of the cut-in (frames after the press).
static func _hold_frame() -> int:
	return SETTLE_FRAMES + roundi((SpecialCutIn.IN_S + SpecialCutIn.HOLD_S * 0.4) / DT)


## The camera is back on the match framing.
static func _after_frame() -> int:
	return SETTLE_FRAMES + roundi((SpecialCutIn.total_seconds() + 0.6) / DT)


func _on_frame() -> void:
	if _world == null:
		_next()
		return
	var first := _index == 0
	if first and _frame == SETTLE_FRAMES:
		_save("before")
	_step(_frame == SETTLE_FRAMES)
	_frame += 1
	if _frame == _hold_frame():
		_save(CharacterData.IDS[_index])
		if not first:
			_teardown()
	elif first and _frame == _after_frame():
		_save("after")
		_teardown()


func _next() -> void:
	_index += 1
	if _index >= CharacterData.IDS.size():
		quit(0)
		return
	var chars: Array[String] = [CharacterData.IDS[_index], CharacterData.DEFAULT]
	_world = World.new(_config, SEED, 2, null, chars)
	_world.fighters[0].pos = Vector3.ZERO
	_world.fighters[0].facing = Vector3(1, 0, 0)
	_world.fighters[0].gauge = SpecialGauge.MAX
	_world.fighters[1].pos = FOE_OFFSET
	_stage = MatchStage.new()
	root.add_child(_stage)
	_stage.setup(_config, SEED, 2)
	_camera = CameraRig.new()
	root.add_child(_camera)
	_camera.setup(_config)
	_director = SpecialCutInDirector.new()
	root.add_child(_director)
	_director.setup(_camera, _reduce)
	_curr = _world.state_view()
	_prev = _curr
	_frame = 0


## One sim tick (slot 0 holds X+C when press), then everything the match draws.
func _step(press: bool) -> void:
	var inputs: Array[InputFrame] = [
		InputFrame.make(0, 0, false, false, true, true) if press else InputFrame.neutral(),
		InputFrame.neutral(),
	]
	_prev = _curr
	_world.tick(inputs)
	_curr = _world.state_view()
	var events: Array = _curr["events"]
	_stage.draw(_prev, _curr, 1.0, DT)
	_stage.on_events(events)
	_director.present(_curr, events, DT)
	_camera.follow(CameraFraming.match_targets(_curr, _config), DT)


func _save(shot_name: String) -> void:
	CaptureArgs.save(root, "%s/cutin-%s%s.png" % [_out, shot_name, _tag])


func _teardown() -> void:
	for n: Node in [_stage, _camera, _director]:
		root.remove_child(n)
		n.free()  # at once, so the next character's camera stays current
	_world = null
