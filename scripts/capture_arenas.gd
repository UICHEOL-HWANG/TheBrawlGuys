extends SceneTree
## Phase 4 T6 evidence: every arena under the match camera at a hazard moment — the classic meadow
## mid-fight, a fighter burning at the lakeside campfire, a broken and a cracking plank on the log
## bridge, a bounce off a mushroom, the fog rolled in with silhouettes above it, and an open and a
## cracking ice patch on the frozen pond.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_arenas.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX] [--only=arena_id]
## Add `--rendering-method gl_compatibility` before -s to check the web renderer.
## Writes <out-dir>/arena-<id><tag>.png per arena.

const PLAYERS := 4
const SEED := 3

var _out: String = ""
var _tag: String = ""
var _shots: Array[Dictionary] = []
var _shot: ArenaShot
var _index: int = -1
var _frame: int = 0


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_tag = String(args.get("tag", ""))
	if _out.is_empty():
		push_error("capture_arenas: usage: -- --out-dir=/abs/dir [--tag=SUFFIX] [--only=id]")
		quit(1)
		return
	var only := String(args.get("only", ""))
	for s: Dictionary in _plan(GameConfig.new()):
		if only.is_empty() or s["id"] == only:
			_shots.append(s)
	process_frame.connect(_on_frame)


## Per arena: sim ticks to skip, frames to draw before the shot and an optional pin
## {fighter, at, from, to} (frames) that holds a fighter on a hazard.
func _plan(c: GameConfig) -> Array[Dictionary]:
	var pad := MushroomForestArena.PAD_RING * Vector3(cos(deg_to_rad(165.0)), 0, sin(deg_to_rad(165.0)))
	var plank_crack := c.platform_break_start_time + c.platform_break_interval + c.platform_warn_time * 0.7
	return [
		{"id": "classic", "skip": 300, "frames": 60},
		{"id": "lakeside_camp", "skip": 240, "frames": 70,
			"pin": {"fighter": 0, "at": LakesideCampArena.CAMPFIRE_CENTER, "from": 0, "to": 45}},
		{"id": "log_bridge", "skip": SimTime.to_ticks(plank_crack) - 60, "frames": 60},
		{"id": "mushroom_forest", "skip": 240, "frames": 58, "pin": {"fighter": 1, "at": pad, "from": 48, "to": 49}},
		{"id": "foggy_forest", "skip": SimTime.to_ticks(c.fog_first_time) - 10, "frames": 100},
		{"id": "frozen_pond", "skip": SimTime.to_ticks(plank_crack) - 60, "frames": 60},
	]


func _on_frame() -> void:
	if _shot == null:
		_next()
		return
	var s := _shots[_index]
	var p: Dictionary = s.get("pin", {})
	if not p.is_empty() and _frame == int(p["from"]):
		_shot.pin(int(p["fighter"]), p["at"])
	if not p.is_empty() and _frame == int(p["to"]):
		_shot.unpin(int(p["fighter"]))
	_shot.step_frame()
	_frame += 1
	if _frame >= int(s["frames"]):
		CaptureArgs.save(root, "%s/arena-%s%s.png" % [_out, s["id"], _tag])
		root.remove_child(_shot)
		_shot.free()  # at once, so the next shot's camera stays current
		_shot = null


func _next() -> void:
	_index += 1
	if _index >= _shots.size():
		quit(0)
		return
	var s := _shots[_index]
	_shot = ArenaShot.new()
	root.add_child(_shot)
	_shot.setup(GameConfig.new(), String(s["id"]), PLAYERS, SEED)
	_shot.fast_forward(int(s["skip"]))
	_frame = 0
