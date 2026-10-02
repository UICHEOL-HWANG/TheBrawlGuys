extends SceneTree
## Evidence for the finishing replay (GD-CAM-02): the real match scene, local versus (P2 idle). P2 is put
## on its last stock at high damage by the arena edge with P1 beside it; P1 holds then releases a
## heavy attack, and shots are taken while the replay plays and once the banner is up.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_finisher.gd -- \
##       --out-dir=/abs/dir
## Writes <out-dir>/finisher-NN.png during the replay and finisher-result.png.

const SETTLE_FRAMES := 30
const HOLD_FRAMES := 20
const SHOT_EVERY := 12
const GIVE_UP_FRAMES := 1200

var _out: String = ""
var _main: Node
var _frame: int = 0
var _shots: int = 0
var _replay_frames: int = 0
## Frames since the banner came up (it pops in, then the shot is taken).
var _result_frames: int = 0
const RESULT_SETTLE_FRAMES := 30


func _init() -> void:
	_out = String(CaptureArgs.parse(OS.get_cmdline_user_args()).get("out-dir", ""))
	if _out.is_empty():
		push_error("capture_finisher: usage: -- --out-dir=/abs/dir")
		quit(1)
		return
	process_frame.connect(_on_frame)


## The match scene loads on the first frame: main.gd uses autoloads, which -s scripts lack in _init.
func _load_match() -> void:
	_main = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	_main.set("setup", MatchSetup.local_versus(2, 7))  # P2 stands still
	root.add_child(_main)


func _on_frame() -> void:
	if _main == null:
		_load_match()
		return
	_frame += 1
	if _frame == SETTLE_FRAMES:
		_stage_the_finish()
		Input.action_press("p1_heavy")
	elif _frame == SETTLE_FRAMES + HOLD_FRAMES:
		Input.action_release("p1_heavy")
	# Untyped for the same reason: Hud and MatchFinale use autoloads.
	var finale: Node = _main.get("_finale")
	var hud: Node = _main.call("get_hud")
	if finale.call("is_playing"):
		if _replay_frames % SHOT_EVERY == 0:
			_shots += 1
			CaptureArgs.save(root, "%s/finisher-%02d.png" % [_out, _shots])
		_replay_frames += 1
	elif hud.call("result_visible") and _replay_frames > 0:
		_result_frames += 1
		if _result_frames < RESULT_SETTLE_FRAMES:
			return
		CaptureArgs.save(root, "%s/finisher-result.png" % _out)
		print("capture_finisher: %d replay frames" % _replay_frames)
		quit(0)
	elif _frame == SETTLE_FRAMES + HOLD_FRAMES + 30:
		var w: World = _main.call("get_world")
		print("capture_finisher: P2 damage %.0f pos %s state %d" % [w.fighters[1].damage, w.fighters[1].pos, w.fighters[1].state])
	elif _frame > GIVE_UP_FRAMES:
		push_error("capture_finisher: no finishing replay (result %s)" % hud.call("result_visible"))
		quit(1)


func _stage_the_finish() -> void:
	var w: World = _main.call("get_world")
	var edge := w.config.arena_radius
	w.fighters[0].pos = Vector3(edge - 2.4, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(edge - 1.4, 0, 0)
	w.fighters[1].stocks = 1
	w.fighters[1].damage = 180.0
