extends SceneTree
## DS-CMP-16 evidence: the KeyHintBar in a live match. Warms up, then per mode:
##   bot (default)  1 vs bot: P1 holds right/jump/heavy (lit) → key-hint-lit; P1's gauge full
##                  (ready ring on the special cap) → key-hint-ready; X+C held (special lit) →
##                  key-hint-special; bar hidden (chip only, not saved) → key-hint-hidden.
##   local_2p       P1 vs P2 (PRD-LOCAL-01): P1 holds X+C, P2 holds A + F with a full gauge →
##                  key-hint-2p (one bar per player, tagged, P2's special cap ringed), then
##                  both bars hidden (one chip left) → key-hint-2p-hidden.
## --ui-scale=F forces the 2D canvas scale (DS-LAY-04 phone = 1.6) after warm-up. The gauge is
## forced on a live fighter (character + gauge) only to show the ring: evidence, not gameplay.
##
## Usage (windowed, NOT headless — it needs a renderer; macOS skips drawing occluded windows, so
## keep the window on top):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_key_hints.gd -- \
##       --out-dir=/abs/dir [--tag=-720] [--mode=bot|local_2p] [--ui-scale=1.6]
## Writes <out-dir>/key-hint-<shot><tag>.png and prints each bar's rect.

const MATCH := "res://src/main/main.tscn"
## Loaded at runtime: typed references to app/HUD classes would pull the Analytics autoload into
## this -s script's compile (it does not exist yet at compile time).
const SETUP_SCRIPT := "res://src/app/match_setup.gd"
const MODE_LOCAL_2P := "local_2p"
const WARMUP_S := 2.5
const STEP_S := 0.3
const READY_CHARACTER := "barbarian"
## [shot name, held actions, slots with a forced full gauge]
const BOT_SHOTS: Array[Array] = [
	["lit", ["p1_right", "p1_jump", "p1_heavy"], []],
	["ready", ["p1_right"], [0]],
	["special", ["p1_heavy", "p1_guard"], []],
]
const LOCAL_2P_SHOTS: Array[Array] = [
	["2p", ["p1_heavy", "p1_guard", "p2_left", "p2_light"], [1]],
]

var _main: Node
var _args: Dictionary = {}
var _shots: Array[Array] = []
var _boot_ms: int = 0
var _step: int = 0
var _step_ms: int = 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_key_hints: usage: -- --out-dir=/abs/dir [--tag=S] [--mode=M] [--ui-scale=F]")
		quit(1)
		return
	var local_2p := String(_args.get("mode", "bot")) == MODE_LOCAL_2P
	_shots = LOCAL_2P_SHOTS if local_2p else BOT_SHOTS
	process_frame.connect(_on_frame.bind(local_2p))


func _on_frame(local_2p: bool) -> void:
	if _main == null:  # autoloads (Analytics) exist from the first frame, not in _init
		_main = (load(MATCH) as PackedScene).instantiate()
		var setup_script := load(SETUP_SCRIPT)
		_main.set("setup", setup_script.call("local_versus" if local_2p else "vs_bots"))
		root.add_child(_main)
		_boot_ms = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _boot_ms < WARMUP_S * 1000.0:
		return
	if _step == 0:
		_start()
	_force_gauges()
	if Time.get_ticks_msec() - _step_ms >= STEP_S * 1000.0:
		_advance()


func _start() -> void:
	Input.warp_mouse(Vector2.ZERO)
	if _args.has("ui-scale"):
		root.content_scale_factor = float(_args["ui-scale"])
	_press(0)
	_step = 1
	_step_ms = Time.get_ticks_msec()


## Saves the current shot, then moves on to the next one (or the hidden bar, then quits).
func _advance() -> void:
	var tag := String(_args.get("tag", ""))
	var index := _step - 1
	if index < _shots.size():
		_save(String(_shots[index][0]), tag)
		_release(index)
		if index + 1 < _shots.size():
			_press(index + 1)
		else:
			for b: KeyHintBar in _hints().call("bars"):
				b.set_state(KeyHintBar.State.HIDDEN)
	elif index == _shots.size():
		_save("2p-hidden" if _shots == LOCAL_2P_SHOTS else "hidden", tag)
		quit(0)
		return
	_step += 1
	_step_ms = Time.get_ticks_msec()


func _press(index: int) -> void:
	for action: String in _shots[index][1]:
		Input.action_press(action)


func _release(index: int) -> void:
	for action: String in _shots[index][1]:
		Input.action_release(action)


## Keeps the current shot's slots at a full gauge and every other slot empty.
func _force_gauges() -> void:
	var index := _step - 1
	var full: Array = _shots[index][2] if index < _shots.size() else []
	var w: World = _main.call("get_world")
	for f: Fighter in w.fighters:
		if full.has(f.id):
			f.character = READY_CHARACTER
			f.gauge = SpecialGauge.MAX
		else:
			f.gauge = 0.0


func _hints() -> Object:
	return _main.call("get_hud").call("key_hints")


func _save(shot: String, tag: String) -> void:
	for b: KeyHintBar in _hints().call("bars"):
		print("capture_key_hints: %s bar %s" % [shot, b.get_global_rect()])
	print("capture_key_hints: viewport %s" % root.get_visible_rect())
	CaptureArgs.save(root, "%s/key-hint-%s%s.png" % [String(_args["out-dir"]), shot, tag])
