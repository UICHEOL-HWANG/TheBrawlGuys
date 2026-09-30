extends SceneTree
## Phase 5 T9 evidence: the character select over the live menu backdrop.
##   bot (default)  1 vs bot: P1 browses to the Knight → char-select-1p-browse; confirms →
##                  char-select-1p-ready (P1-color ring, bot slot "자동 선택").
##   local_2p       P1 stays on the Barbarian, P2 (keys) moves to the Mage and locks in →
##                  char-select-2p (two cursors, P2 ring, P1 choosing / P2 ready, per-player prompts).
## --ui-scale=F sets the 2D canvas scale (DS-LAY-04 phone = 1.6) before the screen is built.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_char_select.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX] [--mode=bot|local_2p] [--ui-scale=1.6]
## Screens name the Analytics autoload, which `-s` scripts cannot compile against, so the scripts
## are loaded at runtime and tracking is a no-op.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const SCREEN := "res://src/app/screens/character_select_screen.gd"
const SETUP := "res://src/app/match_setup.gd"
const UI_LAYER := 10
const WARMUP_FRAMES := 150
const SETTLE_FRAMES := 20

var _args: Dictionary = {}
var _screen: Control
var _backdrop: MenuBackdrop
var _frame: int = 0
var _two: bool = false


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_char_select: usage: -- --out-dir=/abs/dir [--tag=S] [--mode=M] [--ui-scale=F]")
		quit(1)
		return
	_two = String(_args.get("mode", "bot")) == "local_2p"
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 1:
		if _args.has("ui-scale"):
			root.content_scale_factor = float(_args["ui-scale"])
		_add_screen()
		_backdrop.set_focus(_screen.call("backdrop_focus") as Vector2, true)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true  # the OS cursor over the window must not hover cards
	elif _frame == WARMUP_FRAMES:
		for code: Key in ([KEY_D, KEY_D, KEY_F] if _two else [KEY_RIGHT, KEY_RIGHT]):
			_screen.call("_input", _key(code))
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES:
		_save("char-select-2p" if _two else "char-select-1p-browse")
		if _two:
			quit(0)
			return
		_screen.call("_input", _key(KEY_Z))
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES * 2:
		_save("char-select-1p-ready")
		quit(0)


func _add_screen() -> void:
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	root.add_child(ui)
	_screen = (load(SCREEN) as GDScript).new() as Control
	_screen.set("track", func(_n: String, _p: Dictionary) -> void: pass)
	_screen.set("setup", load(SETUP).call("local_versus" if _two else "vs_bots"))
	ui.add_child(_screen)


func _save(shot: String) -> void:
	CaptureArgs.save(root, "%s/%s%s.png" % [String(_args["out-dir"]), shot, String(_args.get("tag", ""))])


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
