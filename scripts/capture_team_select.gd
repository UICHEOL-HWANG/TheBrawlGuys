extends SceneTree
## Evidence for the 2v2 team select: the rule select (팀전 caption) or the team select over the
## live menu backdrop. --screen=team (default) saves team-select-<mode> on the default split, then
## moves one left and saves team-select-<mode>-browse (P1·P2 focused). --screen=rule saves
## rule-select with the 팀전 option focused. --mode=bot (1 human + 3 bots, default) | local_2p.
## --ui-scale=F sets the 2D canvas scale (DS-LAY-04 phone = 1.6) before the screen is built.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_team_select.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX] [--screen=team|rule] [--mode=bot|local_2p] [--ui-scale=1.6]
## Screens name the Analytics autoload, which `-s` scripts cannot compile against, so the scripts
## are loaded at runtime and tracking is a no-op.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const TEAM_SCREEN := "res://src/app/screens/team_select_screen.gd"
const RULE_SCREEN := "res://src/app/screens/rule_select_screen.gd"
const SETUP := "res://src/app/match_setup.gd"
const UI_LAYER := 10
const WARMUP_FRAMES := 150
const SETTLE_FRAMES := 20

var _args: Dictionary = {}
var _screen: Control
var _backdrop: MenuBackdrop
var _frame: int = 0
var _team: bool = true


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_team_select: usage: -- --out-dir=/abs/dir [--tag=S] [--screen=S] [--mode=M] [--ui-scale=F]")
		quit(1)
		return
	_team = String(_args.get("screen", "team")) == "team"
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
		root.gui_disable_input = true  # the OS cursor over the window must not hover buttons
	elif _frame == WARMUP_FRAMES:
		_screen.call("move", -1 if _team else 1)
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES:
		if not _team:
			_save("rule-select")
			quit(0)
			return
		_save("team-select-%s-browse" % _mode())
		_screen.call("move", 1)
	elif _frame == WARMUP_FRAMES + SETTLE_FRAMES * 2:
		_save("team-select-%s" % _mode())
		quit(0)


func _add_screen() -> void:
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	root.add_child(ui)
	_screen = (load(TEAM_SCREEN if _team else RULE_SCREEN) as GDScript).new() as Control
	_screen.set("track", func(_n: String, _p: Dictionary) -> void: pass)
	if _team:
		var setup: Object = load(SETUP).call("local_versus" if _mode() == "local_2p" else "vs_bots")
		setup.call("set_rule", "team")
		_screen.set("setup", setup)
	ui.add_child(_screen)


func _mode() -> String:
	return String(_args.get("mode", "bot"))


func _save(shot: String) -> void:
	CaptureArgs.save(root, "%s/%s%s.png" % [String(_args["out-dir"]), shot, String(_args.get("tag", ""))])
