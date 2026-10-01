extends SceneTree
## Match rule HUD evidence (combat-depth D, DS-LAY-02 v2): a live 4-bot match per rule (stock,
## team, timed) in the real match scene with its HUD strip under the close match camera. After a
## warm-up it saves SHOTS frames per rule and prints, per frame, every fighter's head label point
## on screen and whether it falls under a HUD card, header or the clock (overlap check). Timed: the clock is
## forced to FINAL_S before the last shot so the final-seconds emphasis shows (evidence only).
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_modes.gd -- \
##       --out-dir=/abs/dir [--tag=-720] [--rules=stock,team,timed] [--ui-scale=1.6] [--players=4] [--touch=1]
## --touch=1: P1 is a local player with the touch controls shown (the strip moves to the top).
## Stock keeps --players fighters (4 by default: the 4-player stock FFA strip).
## Writes <out-dir>/hud-<rule>-<n><tag>.png.

const MATCH := "res://src/main/main.tscn"
## Loaded at runtime (typed app/HUD references would compile the Analytics autoload too early).
const SETUP_SCRIPT := "res://src/app/match_setup.gd"
const WARMUP_S := 3.0
const SHOT_EVERY_S := 1.2
const SHOTS := 3
const FINAL_S := 8.0
## Head label height above the feet (FighterIdentity: fighter_height + LABEL_GAP).
const LABEL_GAP := 0.6

var _args: Dictionary = {}
var _rules: PackedStringArray = []
var _rule_index: int = -1
var _main: Node
var _started_ms: int = 0
var _shot: int = 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_modes: usage: -- --out-dir=/abs/dir [--tag=S] [--rules=a,b] [--ui-scale=F]")
		quit(1)
		return
	_rules = String(_args.get("rules", "stock,team,timed")).split(",")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _main == null:
		_next_rule()
		return
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	if _args.has("ui-scale"):
		root.content_scale_factor = float(_args["ui-scale"])  # UiScaler resets it on resize
	if _args.has("touch"):
		(_main.get("_touch") as CanvasLayer).visible = true
	if elapsed < WARMUP_S + SHOT_EVERY_S * _shot:
		return
	if _rules[_rule_index] == "timed" and _shot == SHOTS - 1:
		(_main.call("get_world") as World).mode_state.ticks_left = SimTime.to_ticks(FINAL_S)
		if elapsed < WARMUP_S + SHOT_EVERY_S * _shot + 0.3:
			return  # let the HUD show the forced clock first
	_shot += 1
	_save()
	if _shot >= SHOTS:
		_main.queue_free()
		_main = null


func _next_rule() -> void:
	_rule_index += 1
	if _rule_index >= _rules.size():
		quit(0)
		return
	var setup_script: Script = load(SETUP_SCRIPT)
	var count := int(_args.get("players", 4))
	var setup: Object = setup_script.call("vs_bots", count, 7) if _args.has("touch") \
			else setup_script.call("all_bots", count, 7)
	if _rules[_rule_index] != "stock":
		setup.call("set_rule", _rules[_rule_index])
	setup.call("assign_characters", {})  # seed-drawn characters: names, portraits, gauges
	_main = (load(MATCH) as PackedScene).instantiate()
	_main.set("setup", setup)
	root.add_child(_main)
	_started_ms = Time.get_ticks_msec()
	_shot = 0


func _save() -> void:
	var rule := _rules[_rule_index]
	var name := "hud-%s-%d%s" % [rule, _shot, String(_args.get("tag", ""))]
	_report(name)
	CaptureArgs.save(root, "%s/%s.png" % [String(_args["out-dir"]), name])


## Prints each fighter's label point and whether a top HUD control covers it (canvas coords).
func _report(name: String) -> void:
	var rig: CameraRig = _main.get("_presentation").call("camera_rig")
	var world: World = _main.call("get_world")
	var hud_rects := _hud_rects()
	var to_canvas := root.get_visible_rect().size.y / float(root.size.y)
	var cfg := world.config
	for f: Fighter in world.fighters:
		if not f.is_alive() or rig.camera().is_position_behind(f.pos):
			continue
		var head := f.pos + Vector3.UP * (cfg.fighter_height + LABEL_GAP)
		var at := rig.unproject(head) * to_canvas
		var covered := hud_rects.any(func(r: Rect2) -> bool: return r.has_point(at))
		print("capture_modes: %s P%d label=%s covered=%s" % [name, f.id + 1, at.round(), covered])
	print("capture_modes: %s hud=%s viewport=%s" % [name, _hud_band(hud_rects), root.get_visible_rect().size])


func _hud_rects() -> Array[Rect2]:
	var strip: Object = _main.call("get_hud").call("strip")
	var out: Array[Rect2] = []
	for c: Variant in strip.get("cards"):
		out.append((c as Control).get_global_rect())
	for h: Variant in strip.get("headers"):
		out.append((h as Control).get_global_rect())
	if strip.get("timer") != null:
		out.append((strip.get("timer") as Control).get_global_rect())
	return out


## The strip's band: "top..bottom" in canvas pixels.
func _hud_band(rects: Array[Rect2]) -> String:
	var top := INF
	var bottom := 0.0
	for r: Rect2 in rects:
		top = minf(top, r.position.y)
		bottom = maxf(bottom, r.end.y)
	return "%d..%d" % [roundi(top), roundi(bottom)]
