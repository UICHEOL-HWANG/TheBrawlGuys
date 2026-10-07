extends SceneTree
## Evidence for the settings screen: SettingsScreen over the live menu backdrop, with synthetic
## volumes so the sliders show different fills.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_settings.gd -- \
##       --out=/abs/settings.png [--ui-scale=1.6]
## --ui-scale=F sets the 2D canvas scale (DS-LAY-04 phone = 1.6) before the screen is built.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
## Loaded at runtime: the screen names the Analytics autoload, which `-s` scripts cannot compile against.
const SCREEN := "res://src/app/screens/settings_screen.gd"
const TEMP_STORE := "user://capture_settings.cfg"
const WARMUP_FRAMES := 150

var _out: String = ""
var _scale: float = 1.0
var _screen: Control
var _backdrop: MenuBackdrop
var _frame: int = 0


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out", ""))
	_scale = float(args.get("ui-scale", "1.0"))
	if _out.is_empty():
		push_error("capture_settings: usage: -- --out=/abs/settings.png")
		quit(1)
		return
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 1:
		root.content_scale_factor = _scale
		var store := SettingsStore.new(TEMP_STORE)
		UserVolume.set_percent(store, UserVolume.SFX, 60)
		UserVolume.set_percent(store, UserVolume.MUSIC, 30)
		var screen := (load(SCREEN) as GDScript).new() as Control
		screen.set("store", store)
		screen.set("track", func(_n: String, _p: Dictionary) -> void: pass)
		screen.set("device_key", "capture")  # no device id written; the switch shows that bucket's arm
		var layer := CanvasLayer.new()
		layer.layer = 10
		root.add_child(layer)
		layer.add_child(screen)
		_screen = screen
		_backdrop.set_focus(screen.call("backdrop_focus") as Vector2, true)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true
	elif _frame == WARMUP_FRAMES:
		CaptureArgs.save(root, _out)
		DirAccess.remove_absolute(TEMP_STORE)
		quit(0)
