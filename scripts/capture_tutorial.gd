extends SceneTree
## Phase 5 T11 evidence: the onboarding tutorial scene. Warms up, then shoots
##   mission   first mission (이동): card + ringed arrow caps
##   success   the move mission cleared: "좋아요!"
##   jump      the jump mission (ringed jump cap; on touch the ringed jump button)
##   grab      the grab & throw mission (ringed V cap)
##   special   the special mission: full gauge (fire ring) + ringed X+C
##   skip      the skip dialog over the paused scene
##   complete  every mission done: "튜토리얼 완료!" + 타이틀로
## Missions are cleared by completing their goals directly (evidence, not gameplay); progress is
## kept in a scratch settings file. --touch=1 shows the touch controls (touch instruction lines and
## ringed buttons), --still=1 turns reduce motion on (still rings), --ui-scale=F forces the 2D
## canvas scale (DS-LAY-04 phone = 1.6).
##
## Usage (windowed, NOT headless; keep the window on top):
##   godot --path . --resolution 1920x1080 --always-on-top -s res://scripts/capture_tutorial.gd -- \
##       --out-dir=/abs/dir [--tag=-phone] [--touch=1] [--still=1] [--ui-scale=1.6]
## Writes <out-dir>/tutorial-<shot><tag>.png.

const SCENE := "res://src/tutorial/tutorial_match.tscn"
const PROGRESS_PATH := "user://capture_tutorial.cfg"
const SETTINGS_PATH := "user://capture_tutorial_settings.cfg"
const WARMUP_S := 2.5
const STEP_S := 0.7
const SHOTS: Array[String] = ["mission", "success", "jump", "grab", "special", "skip", "complete"]
## Mission index each shot opens on (-1 = no change).
const SHOT_STEP := {"jump": 1, "grab": 5, "special": 7}

var _scene: Node
var _args: Dictionary = {}
var _boot_ms: int = 0
var _shot: int = -1
var _shot_ms: int = 0


func _init() -> void:
	_args = CaptureArgs.parse(OS.get_cmdline_user_args())
	if String(_args.get("out-dir", "")).is_empty():
		push_error("capture_tutorial: usage: -- --out-dir=/abs/dir [--tag=S] [--touch=1] [--still=1] [--ui-scale=F]")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _scene == null:  # autoloads (Analytics) exist from the first frame, not in _init
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
		_scene = (load(SCENE) as PackedScene).instantiate()
		_scene.set("progress", TutorialProgress.new(SettingsStore.new(PROGRESS_PATH)))
		_scene.set("track", func(_n: String, _p: Dictionary) -> void: pass)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
		var settings := SettingsStore.new(SETTINGS_PATH)
		settings.set_value(SpecialCutInDirector.SETTINGS_SECTION, SpecialCutInDirector.SETTINGS_KEY,
				String(_args.get("still", "")) == "1")
		_scene.set("settings", settings)
		root.add_child(_scene)
		_boot_ms = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _boot_ms < WARMUP_S * 1000.0:
		return
	if _shot < 0:
		_begin()
	elif Time.get_ticks_msec() - _shot_ms >= STEP_S * 1000.0:
		_save_and_next()


func _begin() -> void:
	Input.warp_mouse(Vector2.ZERO)
	if _args.has("ui-scale"):
		root.content_scale_factor = float(_args["ui-scale"])
	if String(_args.get("touch", "")) == "1":
		(_scene.get("_touch") as CanvasLayer).visible = true
	_open(0)


func _save_and_next() -> void:
	var tag := String(_args.get("tag", ""))
	CaptureArgs.save(root, "%s/tutorial-%s%s.png" % [_args["out-dir"], SHOTS[_shot], tag])
	if _shot + 1 >= SHOTS.size():
		quit(0)
		return
	_open(_shot + 1)


## Sets the scene up for shot i.
func _open(i: int) -> void:
	_shot = i
	_shot_ms = Time.get_ticks_msec()
	var flow: TutorialFlow = (_scene.call("director") as TutorialDirector).flow
	var overlay: CanvasLayer = _scene.call("overlay")
	match SHOTS[i]:
		"success":
			_clear_goal(flow)
		"skip":
			overlay.call("open_dialog")
		"complete":
			overlay.call("close_dialog")
			_run_to(flow, TutorialSteps.count())
	if SHOT_STEP.has(SHOTS[i]):
		_run_to(flow, int(SHOT_STEP[SHOTS[i]]))


## Clears missions until mission `index` is on (count = finish the tutorial).
func _run_to(flow: TutorialFlow, index: int) -> void:
	while not flow.is_done() and (flow.index() < index or flow.phase() != TutorialFlow.Phase.RUNNING):
		if flow.phase() == TutorialFlow.Phase.CELEBRATING:
			flow.advance()
		else:
			_clear_goal(flow)


## Evidence only: completes the current goal as its detector would.
func _clear_goal(flow: TutorialFlow) -> void:
	flow.call("_goal_met")
