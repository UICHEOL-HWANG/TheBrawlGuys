extends SceneTree
## DS-CMP-16 evidence: the KeyHintBar in a live 1 vs bot match. Warms up, holds a few P1 actions
## (lit caps), then hides the bar (chip only, not saved to settings) and captures both.
##
## Usage (windowed, NOT headless — it needs a renderer; macOS skips drawing occluded windows, so
## keep the window on top):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_key_hints.gd -- \
##       --out-dir=/abs/dir [--tag=-720]
## Writes <out-dir>/key-hint-lit<tag>.png and <out-dir>/key-hint-hidden<tag>.png.

const MATCH := "res://src/main/main.tscn"
const WARMUP_S := 2.5
const HOLD_S := 0.25
const HIDE_S := 0.5
const HELD: Array[String] = ["p1_right", "p1_jump", "p1_heavy"]

var _main: Node
var _prefix: String = ""
var _boot_ms: int = 0
var _step: int = 0


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var out_dir := String(args.get("out-dir", ""))
	if out_dir.is_empty():
		push_error("capture_key_hints: usage: -- --out-dir=/abs/dir [--tag=SUFFIX]")
		quit(1)
		return
	_prefix = "%s/key-hint" % out_dir
	process_frame.connect(_on_frame.bind(String(args.get("tag", ""))))


func _on_frame(tag: String) -> void:
	if _main == null:  # autoloads (Analytics) exist from the first frame, not in _init
		_main = (load(MATCH) as PackedScene).instantiate()
		root.add_child(_main)
		_boot_ms = Time.get_ticks_msec()
		return
	var t := (Time.get_ticks_msec() - _boot_ms) / 1000.0
	if _step == 0 and t >= WARMUP_S:
		Input.warp_mouse(Vector2.ZERO)
		for action: String in HELD:
			Input.action_press(action)
		_step = 1
	elif _step == 1 and t >= WARMUP_S + HOLD_S:
		_save("%s-lit%s.png" % [_prefix, tag])
		for action: String in HELD:
			Input.action_release(action)
		var hints: Control = _main.call("get_hud").call("key_hints")
		(hints.call("bar") as KeyHintBar).set_state(KeyHintBar.State.HIDDEN)
		_step = 2
	elif _step == 2 and t >= WARMUP_S + HOLD_S + HIDE_S:
		_save("%s-hidden%s.png" % [_prefix, tag])
		quit(0)


func _save(path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	if err != OK:
		push_error("capture_key_hints: cannot save %s (%s)" % [path, error_string(err)])
		quit(1)
		return
	print("capture_key_hints: saved %s" % path)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			out[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	return out
