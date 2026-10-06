extends SceneTree
## Evidence for the settings screen: SettingsScreen over the live menu backdrop, with synthetic
## volumes so the sliders show different fills.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_settings.gd -- \
##       --out=/abs/settings.png

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const TEMP_STORE := "user://capture_settings.cfg"
const WARMUP_FRAMES := 150

var _out: String = ""
var _screen: Control
var _backdrop: MenuBackdrop
var _frame: int = 0


func _init() -> void:
	_out = String(CaptureArgs.parse(OS.get_cmdline_user_args()).get("out", ""))
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
		var store := SettingsStore.new(TEMP_STORE)
		UserVolume.set_percent(store, UserVolume.SFX, 60)
		UserVolume.set_percent(store, UserVolume.MUSIC, 30)
		var screen := SettingsScreen.new()
		screen.store = store
		var layer := CanvasLayer.new()
		layer.layer = 10
		root.add_child(layer)
		layer.add_child(screen)
		_screen = screen
		_backdrop.set_focus(screen.backdrop_focus(), true)
		Input.warp_mouse(Vector2.ZERO)
		root.gui_disable_input = true
	elif _frame == WARMUP_FRAMES:
		CaptureArgs.save(root, _out)
		DirAccess.remove_absolute(TEMP_STORE)
		quit(0)
