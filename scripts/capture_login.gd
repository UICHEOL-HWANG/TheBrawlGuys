extends SceneTree
## DS-CMP-14 evidence: the LoginPanel over the live menu backdrop. Lets the bots brawl for a
## warm-up, plays the entrance and saves a frame sequence across it plus the settled screen.
##
## Usage (windowed, NOT headless — it needs a renderer; macOS skips drawing occluded windows, so
## keep the window on top):
##   godot --path . --resolution 1920x1080 --always-on-top -s res://scripts/capture_login.gd -- \
##       --out-dir=/abs/dir [--tag=-720] [--warmup=4]
## Writes <out-dir>/login-final<tag>-f<k>.png (k = 0..5) and <out-dir>/login-final<tag>.png.
## The haze reveal and the card entrance start together, as on the real first screen.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const PANEL := "res://src/ui/components/login_panel/login_panel.tscn"
const UI_LAYER := 10
const DEFAULT_WARMUP_S := 4.0
## Seconds after the entrance starts: haze clearing + card rising, then the contents stagger in.
const SEQUENCE_S: Array[float] = [0.05, 0.25, 0.45, 0.65, 0.9, 1.2]
const FINAL_S := 2.4

var _panel: LoginPanel
var _backdrop: MenuBackdrop
var _prefix: String = ""
var _warmup_s: float = DEFAULT_WARMUP_S
var _focused: bool = false
var _started_ms: int = -1
var _boot_ms: int = 0
var _next: int = 0


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var out_dir := String(args.get("out-dir", ""))
	if out_dir.is_empty():
		push_error("capture_login: usage: -- --out-dir=/abs/dir [--tag=SUFFIX] [--warmup=S]")
		quit(1)
		return
	_warmup_s = float(args.get("warmup", str(DEFAULT_WARMUP_S)))
	_prefix = "%s/login-final%s" % [out_dir, String(args.get("tag", ""))]
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	root.add_child(ui)
	_panel = (load(PANEL) as PackedScene).instantiate() as LoginPanel
	_panel.modulate.a = 0.0  # laid out but unseen until the entrance
	ui.add_child(_panel)
	_boot_ms = Time.get_ticks_msec()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	var now := Time.get_ticks_msec()
	if not _focused:  # nodes are ready from the first frame on
		_backdrop.set_focus(_panel.backdrop_focus(), true)
		Input.warp_mouse(Vector2.ZERO)  # no hover ring on the captured button
		_focused = true
	if _started_ms < 0:
		if now - _boot_ms >= int(_warmup_s * 1000.0):
			_panel.modulate.a = 1.0
			_backdrop.reveal()
			_panel.play_entrance()
			_started_ms = now
		return
	var t := (now - _started_ms) / 1000.0
	if _next < SEQUENCE_S.size() and t >= SEQUENCE_S[_next]:
		_save("%s-f%d.png" % [_prefix, _next])
		_next += 1
	elif _next >= SEQUENCE_S.size() and t >= FINAL_S:
		_save("%s.png" % _prefix)
		quit(0)


func _save(path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	if err != OK:
		push_error("capture_login: cannot save %s (%s)" % [path, error_string(err)])
		quit(1)
		return
	print("capture_login: saved %s" % path)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			out[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	return out
