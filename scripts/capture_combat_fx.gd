extends SceneTree
## Combat effects evidence (combat-motion B1-B3) under the real match camera: the Mage's bolt,
## heavy bolt and big fireball (charge, flight, blast), the Barbarian's slam, the Knight's spin,
## the Rogue's rush and a grab connecting then holding. The sim runs one tick per frame; all FX
## are render-only (MatchStage's CombatFxLayer).
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_combat_fx.gd -- \
##       --out-dir=/abs/dir [--only=NAME]
## Writes <out-dir>/fx-<scene>-<tick>.png (event shots: fx-<scene>-<event>+<n>.png).

const DT := 1.0 / 60.0
const SEED := 3
const SETTLE := 30
const GAP := 4.0
## name, characters, attacker input kind, shots (ticks after the input), event-relative shots.
const SCENES := [
	{"name": "bolt", "chars": ["mage", "knight"], "do": "light", "shots": [8, 14], "event": "projectile_hit", "after": [1, 5]},
	{"name": "heavy", "chars": ["mage", "knight"], "do": "heavy", "shots": [30, 34], "event": "projectile_hit", "after": [2]},
	{"name": "fireball", "chars": ["mage", "knight"], "do": "special", "shots": [4, 10, 15, 20, 26], "event": "special_hit", "after": [1, 4, 10]},
	{"name": "slam", "chars": ["barbarian", "knight"], "do": "special", "shots": [3, 13, 16, 20], "gap": 2.2},
	{"name": "spin", "chars": ["knight", "barbarian"], "do": "special", "shots": [12, 15, 18], "gap": 1.8},
	{"name": "rush", "chars": ["rogue", "knight"], "do": "special", "shots": [16, 24], "gap": 5.0},
	{"name": "grab", "chars": ["knight", "barbarian"], "do": "grab", "shots": [], "gap": 1.0, "event": "grab", "after": [2, 5, 20]},
]

var _out: String = ""
var _only: String = ""
var _index: int = -1
var _frame: int = 0
var _event_frame: int = -1
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
	_only = String(args.get("only", ""))
	if _out.is_empty():
		push_error("capture_combat_fx: usage: -- --out-dir=/abs/dir [--only=NAME]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _world == null:
		_next()
		return
	var scene: Dictionary = SCENES[_index]
	var t := _frame - SETTLE
	if _step(t, scene) and _event_frame < 0:
		_event_frame = _frame
	_frame += 1
	if t in scene["shots"]:
		_save("fx-%s-%d" % [scene["name"], t])
	if _event_frame >= 0:
		var n := _frame - 1 - _event_frame
		if n in scene.get("after", []):
			_save("fx-%s-%s+%d" % [scene["name"], scene["event"], n])
	if t > 140:
		_teardown()


func _next() -> void:
	_index += 1
	while _index < SCENES.size() and not _only.is_empty() and SCENES[_index]["name"] != _only:
		_index += 1
	if _index >= SCENES.size():
		quit(0)
		return
	var scene: Dictionary = SCENES[_index]
	var chars: Array[String] = []
	chars.assign(scene["chars"])
	_world = World.new(_config, SEED, 2, null, chars)
	var gap := float(scene.get("gap", GAP))
	_world.fighters[0].pos = Vector3(-gap * 0.5, 0, 0)
	_world.fighters[0].facing = Vector3(1, 0, 0)
	_world.fighters[1].pos = Vector3(gap * 0.5, 0, 0)
	_world.fighters[1].facing = Vector3(-1, 0, 0)
	_stage = MatchStage.new()
	root.add_child(_stage)
	_stage.setup(_config, SEED, 2, ArenaCatalog.DEFAULT_ID, chars)
	_camera = CameraRig.new()
	root.add_child(_camera)
	_camera.setup(_config)
	_feel = FeelDirector.new()
	root.add_child(_feel)
	_feel.setup(_config, _camera)
	_curr = _world.state_view()
	_prev = _curr
	_frame = 0
	_event_frame = -1


## One sim tick of the scene (t < 0 = settling) and everything the match draws. True when the
## scene's event happened this tick.
func _step(t: int, scene: Dictionary) -> bool:
	var act := String(scene["do"])
	if act == "special" and t == -1:
		_world.fighters[0].gauge = SpecialGauge.MAX
	var light := act == "light" and t == 0
	var heavy := (act == "heavy" and t >= 0 and t < 20) or (act == "special" and t == 0)
	var guard := act == "special" and t == 0
	var grab := act == "grab" and t == 0
	var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, light, heavy, guard, grab), InputFrame.make(0, 0)]
	_prev = _curr
	_world.tick(inputs)
	_curr = _world.state_view()
	var events: Array = _curr["events"]
	_stage.draw(_prev, _curr, 1.0, DT)
	_stage.on_events(events)
	_feel.on_events(events, _curr["fighters"])
	_camera.follow(CameraFraming.match_targets(_curr, _config), DT)
	for e: Dictionary in events:
		if String(e["type"]) == String(scene.get("event", "")):
			return true
	return false


func _save(shot_name: String) -> void:
	CaptureArgs.save(root, "%s/%s.png" % [_out, shot_name])


func _teardown() -> void:
	for n: Node in [_stage, _camera, _feel]:
		root.remove_child(n)
		n.free()
	_world = null
