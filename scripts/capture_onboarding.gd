extends SceneTree
## Onboarding evidence (design.md DS-LAY-03 온보딩): each screen over the live menu backdrop —
## onboarding-welcome, onboarding-nickname (prefilled), onboarding-nickname-error (one letter,
## submitted), onboarding-choice ("브롤왕" picked). --ui-scale=F sets the 2D canvas scale (DS-LAY-04
## phone = 1.6) before the screens are built.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1920x1080 --always-on-top -s res://scripts/capture_onboarding.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX] [--ui-scale=1.6]
## Screens name the Analytics autoload, which `-s` scripts cannot compile against, so the scripts
## are loaded at runtime.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const DIR := "res://src/app/screens/onboarding/"
const SHOTS: Array[String] = ["welcome", "nickname", "nickname-error", "choice"]
const UI_LAYER := 10
const WARMUP_FRAMES := 120
const SETTLE_FRAMES := 30

var _args: Dictionary = {}
var _backdrop: MenuBackdrop
var _ui: CanvasLayer
var _screen: Control
var _shot: int = -1
var _frame: int = 0
## Frame the current screen is shot on.
var _due: int = 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_onboarding: usage: -- --out-dir=/abs/dir [--tag=S] [--ui-scale=F]")
		quit(1)
		return
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 1:
		if _args.has("ui-scale"):
			root.content_scale_factor = float(_args["ui-scale"])
		_ui = CanvasLayer.new()
		_ui.layer = UI_LAYER
		root.add_child(_ui)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true  # the OS cursor must not hover buttons
	elif _frame == 2 or _frame == _due:
		if _shot >= 0:
			CaptureArgs.save(root, "%s/onboarding-%s%s.png" % [_args["out-dir"], SHOTS[_shot], _args.get("tag", "")])
		_next()


func _next() -> void:
	_shot += 1
	if _shot >= SHOTS.size():
		quit(0)
		return
	if _screen != null:
		_ui.remove_child(_screen)
		_screen.free()
	var file := {"welcome": "welcome_screen", "nickname": "nickname_screen", "nickname-error": "nickname_screen",
		"choice": "onboarding_choice_screen"}[SHOTS[_shot]] as String
	_screen = (load(DIR + file + ".gd") as GDScript).new() as Control
	_ui.add_child(_screen)
	_due = _frame + SETTLE_FRAMES + (WARMUP_FRAMES if _shot == 0 else 0)
	_backdrop.set_focus(_screen.call("backdrop_focus") as Vector2, true)
	match SHOTS[_shot]:
		"nickname":
			_screen.call("set_prefill", "브롤왕")
		"nickname-error":
			(_screen.call("field") as LineEdit).text = "a"
			_screen.call("submit")
