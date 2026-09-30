extends SceneTree
## Phase 5 T9 evidence (design.md DS-VIS-03): four fighters, each playing its drawn character,
## lined up in a live match so their foot rings (P1 circle, P2 triangle, P3 square, P4 diamond)
## and P-labels show side by side — saved in color (player-ids) and in grayscale
## (player-ids-gray) to prove the players read apart without color. The fighters are held in
## place each frame only for the shot: evidence, not gameplay.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_player_ids.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX]

const MATCH := "res://src/main/main.tscn"
const SETUP := "res://src/app/match_setup.gd"
const PLAYERS := 4
const SEED := 7
const WARMUP_S := 2.0
const HOLD_S := 0.8
const SPOTS: Array[Vector3] = [Vector3(-4.5, 0, 1), Vector3(-1.5, 0, 1), Vector3(1.5, 0, 1), Vector3(4.5, 0, 1)]

var _args: Dictionary = {}
var _main: Node
var _boot_ms: int = 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_player_ids: usage: -- --out-dir=/abs/dir [--tag=S]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _main == null:  # autoloads exist from the first frame, not in _init
		var setup: RefCounted = load(SETUP).call("all_bots", PLAYERS, SEED)
		setup.call("assign_characters", {})
		_main = (load(MATCH) as PackedScene).instantiate()
		_main.set("setup", setup)
		root.add_child(_main)
		_boot_ms = Time.get_ticks_msec()
		print("capture_player_ids: characters %s" % [setup.call("characters")])
		return
	var elapsed := (Time.get_ticks_msec() - _boot_ms) / 1000.0
	if elapsed < WARMUP_S:
		return
	_hold()
	if elapsed >= WARMUP_S + HOLD_S:
		_save()
		quit(0)


## Every fighter on its spot, facing the camera side, standing still.
func _hold() -> void:
	var w: World = _main.call("get_world")
	for f: Fighter in w.fighters:
		f.pos = SPOTS[f.id]
		f.vel = Vector3.ZERO
		f.facing = Vector3(0, 0, 1)


func _save() -> void:
	var out := String(_args["out-dir"])
	var tag := String(_args.get("tag", ""))
	CaptureArgs.save(root, "%s/player-ids%s.png" % [out, tag])
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_L8)
	var path := "%s/player-ids-gray%s.png" % [out, tag]
	if img.save_png(path) == OK:
		print("capture: saved %s" % path)
	else:
		push_error("capture_player_ids: cannot save %s" % path)
