extends SceneTree
## Phase 4 T7 evidence: the arena select screen over the live menu backdrop — one shot with the
## second card focused (browsing), one right after confirming it (selected).
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_arena_select.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX]
## Writes <out-dir>/arena-select-focus<tag>.png and <out-dir>/arena-select-chosen<tag>.png.
## App screens name the Analytics autoload, which `-s` scripts cannot compile against, so the
## screen script is loaded at runtime (after the autoloads exist) and its tracking is a no-op.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const SCREEN := "res://src/app/screens/arena_select_screen.gd"
const UI_LAYER := 10
const WARMUP_FRAMES := 150
const SETTLE_FRAMES := 20

var _out: String = ""
var _tag: String = ""
var _screen: Control
var _backdrop: MenuBackdrop
var _frame: int = 0


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_tag = String(args.get("tag", ""))
	if _out.is_empty():
		push_error("capture_arena_select: usage: -- --out-dir=/abs/dir [--tag=SUFFIX]")
		quit(1)
		return
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 1:
		_add_screen()
		_backdrop.set_focus(_screen.call("backdrop_focus") as Vector2, true)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true  # the OS cursor over the window must not hover or click cards
	elif _frame == WARMUP_FRAMES:
		_screen.call("move", 1)
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES:
		CaptureArgs.save(root, "%s/arena-select-focus%s.png" % [_out, _tag])
		_screen.call("confirm")
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES * 2:
		CaptureArgs.save(root, "%s/arena-select-chosen%s.png" % [_out, _tag])
		quit(0)


func _add_screen() -> void:
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	root.add_child(ui)
	_screen = (load(SCREEN) as GDScript).new() as Control
	_screen.set("track", func(_n: String, _p: Dictionary) -> void: pass)
	ui.add_child(_screen)
