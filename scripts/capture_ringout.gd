extends SceneTree
## Ring-out evidence: the real match scene (local versus, P2 idle) on one arena. P1 is placed by
## an edge and either walks off it (--case=walk) or P2 is launched off it (--case=launch); the
## match camera is photographed every few frames until the ring-out, and the shots are laid out
## as one contact sheet.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_ringout.gd -- \
##       --out-dir=/abs/dir [--arena=classic] [--case=walk]
## Writes <out-dir>/ringout-<arena>-<case>.png.

const SETTLE_FRAMES := 30
const SHOT_EVERY := 4
const AFTER_FRAMES := 40
const GIVE_UP_FRAMES := 600
const THUMB := Vector2i(400, 225)
const COLUMNS := 5

var _out: String = ""
var _arena: String = "classic"
var _case: String = "walk"
var _main: Node
var _frame: int = 0
var _thumbs: Array[Image] = []
var _ringout_at: int = -1


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_arena = String(args.get("arena", _arena))
	_case = String(args.get("case", _case))
	if _out.is_empty():
		push_error("capture_ringout: usage: -- --out-dir=/abs/dir [--arena=id] [--case=walk|launch]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _load_match() -> void:
	_main = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var setup := MatchSetup.local_versus(2, 7)
	setup.arena_id = _arena
	_main.set("setup", setup)
	root.add_child(_main)


func _on_frame() -> void:
	if _main == null:
		_load_match()
		return
	_frame += 1
	if _frame == SETTLE_FRAMES:
		_stage()
	if _frame < SETTLE_FRAMES:
		return
	var w: World = _main.call("get_world")
	if _ringout_at < 0 and w.fighters[_victim()].stocks < 3:
		_ringout_at = _frame
	if (_frame - SETTLE_FRAMES) % SHOT_EVERY == 0:
		var img := root.get_texture().get_image()
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		_thumbs.append(img)
	if (_ringout_at > 0 and _frame > _ringout_at + AFTER_FRAMES) or _frame > GIVE_UP_FRAMES:
		Input.action_release("p1_right")
		_write()
		quit(0 if _ringout_at > 0 else 1)


func _victim() -> int:
	return 0 if _case == "walk" else 1


## P1 by the +x edge facing out. walk: hold right. launch: P2 at the edge, flung outward.
func _stage() -> void:
	var w: World = _main.call("get_world")
	var edge := _edge_x(w.arena)
	w.fighters[0].pos = Vector3(edge - 1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(edge - 0.5, 0, 1.5)
	if _case == "walk":
		Input.action_press("p1_right")
		return
	var f := w.fighters[1]
	f.vel = Vector3(14.0, 9.0, 0.0)
	f.on_ground = false
	f.tumble = true
	f.hitstun_ticks = 40
	f.set_state(Fighter.State.HITSTUN)


static func _edge_x(arena: ArenaData) -> float:
	var x := 0.0
	while x < 60.0 and ArenaFloor.over_floor(arena, Vector3(x + 0.1, 0, 0)):
		x += 0.1
	return x


func _write() -> void:
	if _thumbs.is_empty():
		return
	var rows := ceili(float(_thumbs.size()) / COLUMNS)
	var sheet := Image.create(THUMB.x * COLUMNS, THUMB.y * rows, false, _thumbs[0].get_format())
	for i: int in _thumbs.size():
		sheet.blit_rect(_thumbs[i], Rect2i(Vector2i.ZERO, THUMB), Vector2i(i % COLUMNS * THUMB.x, i / COLUMNS * THUMB.y))
	var path := "%s/ringout-%s-%s.png" % [_out, _arena, _case]
	sheet.save_png(path)
	print("capture_ringout: %d shots, ring-out at frame %d -> %s" % [_thumbs.size(), _ringout_at, path])
