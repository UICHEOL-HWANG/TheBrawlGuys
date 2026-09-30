extends SceneTree
## DS-CMP-14 email mode evidence (platform B6): the login card over the live menu backdrop in
## four states — methods (Google + "이메일로 계속하기"), email step, code step (cooldown running)
## and a wrong-code error. No network: the card is driven directly with fake values.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_login_email.gd -- \
##       --out-dir=/abs/dir [--warmup=3]
## Writes <out-dir>/login-email-{methods,step,code,error}.png.

const BACKDROP := "res://src/app/menu_backdrop/menu_backdrop.tscn"
const PANEL := "res://src/ui/components/login_panel/login_panel.tscn"
const UI_LAYER := 10
const DEFAULT_WARMUP_S := 3.0
## Seconds per state: the swap fade (motion_base) and focus rings settle well within this.
const STATE_S := 0.8
const EMAIL := "player@example.com"
## Loaded at run time: LoginMessages reaches the Analytics autoload, absent when -s compiles us.
const MESSAGES := "res://src/app/screens/login_messages.gd"
const STATES: Array[String] = ["methods", "step", "code", "error"]

var _panel: LoginPanel
var _backdrop: MenuBackdrop
var _out_dir: String = ""
var _warmup_s: float = DEFAULT_WARMUP_S
var _boot_ms: int = 0
var _next: int = 0
var _staged_ms: int = -1


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	_out_dir = String(args.get("out-dir", ""))
	if _out_dir.is_empty():
		push_error("capture_login_email: usage: -- --out-dir=/abs/dir [--warmup=S]")
		quit(1)
		return
	_warmup_s = float(args.get("warmup", str(DEFAULT_WARMUP_S)))
	_backdrop = (load(BACKDROP) as PackedScene).instantiate() as MenuBackdrop
	root.add_child(_backdrop)
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	root.add_child(ui)
	_panel = (load(PANEL) as PackedScene).instantiate() as LoginPanel
	ui.add_child(_panel)
	_boot_ms = Time.get_ticks_msec()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	var now := Time.get_ticks_msec()
	if _staged_ms < 0:
		if now - _boot_ms < int(_warmup_s * 1000.0):
			return
		_backdrop.set_focus(_panel.backdrop_focus(), true)
		_backdrop.reveal()
		Input.warp_mouse(Vector2.ZERO)  # no hover ring on the captured buttons
		_stage(STATES[_next])
		_staged_ms = now
		return
	if now - _staged_ms < int(STATE_S * 1000.0):
		return
	_save("%s/login-email-%s.png" % [_out_dir, STATES[_next]])
	_next += 1
	if _next >= STATES.size():
		quit(0)
		return
	_stage(STATES[_next])
	_staged_ms = now


func _stage(state: String) -> void:
	var view := _panel.email_view()
	match state:
		"methods":
			_panel.google_button().grab_focus()
		"step":
			_panel.show_email()
			view.email_field().text = EMAIL
			view.email_field().caret_column = EMAIL.length()
		"code":
			view.show_step(EmailLoginView.Step.CODE)
			view.set_message(_message("CODE_SENT"), false)
			view.set_cooldown(42)
			view.code_input().set_code("4829")
			view.code_input().grab_input_focus()
		"error":
			view.code_input().clear()
			view.set_message(_message("WRONG_CODE"), true)
			view.set_cooldown(17)


static func _message(key: String) -> String:
	return String((load(MESSAGES) as GDScript).get_script_constant_map()[key])


func _save(path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	if err != OK:
		push_error("capture_login_email: cannot save %s (%s)" % [path, error_string(err)])
		quit(1)
		return
	print("capture_login_email: saved %s" % path)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			out[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	return out
