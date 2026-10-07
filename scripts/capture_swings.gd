extends SceneTree
## combat-motion evidence: contact sheets of every swing. Each row is one swing drawn by six
## FighterViews frozen at the start, mid-windup, the first active tick (the strike), the end of
## the active frames, mid-recovery and the last tick; rows stack per character into one PNG.
## The grab sheet adds a holder with the fighter held in front of it.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1500x300 --always-on-top -s res://scripts/capture_swings.gd -- \
##       --out-dir=/abs/dir
## Writes <out-dir>/swings-<character>.png and swings-grab.png.

const K := AttackSet.Kind
const SHEETS := {
	"barbarian": [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3, K.HEAVY, K.SPECIAL],
	"knight": [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3, K.HEAVY],
	"mage": [K.LIGHT_1, K.HEAVY, K.SPECIAL],
	"grab": [K.GRAB],
}
const COLUMNS := 6
const GETUP := -2  # the getup attack (state GETUP, getup_ticks)
const TUMBLE := -3  # a tumbling launch, flown for longer in each column
const GAP := 2.1
const SETTLE_FRAMES := 3

var _out: String = ""
var _config := GameConfig.new()
var _jobs: Array = []  # [sheet, kind]
var _strips: Dictionary = {}  # sheet -> Array[Image]
var _views: Array[FighterView] = []
var _phase: int = 0


func _init() -> void:
	_out = String(CaptureArgs.parse(OS.get_cmdline_user_args()).get("out-dir", ""))
	if _out.is_empty():
		push_error("capture_swings: usage: -- --out-dir=/abs/dir")
		quit(1)
		return
	for sheet: String in SHEETS:
		for kind: int in SHEETS[sheet]:
			_jobs.append([sheet, kind])
	_jobs.append(["grab", -1])  # holder + held pair
	_jobs.append(["getup", GETUP])
	_jobs.append(["getup", TUMBLE])
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _phase == 0:
		CaptureArgs.grass_stage(root)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.6
		root.add_child(cam)
		cam.look_at_from_position(Vector3(GAP * (COLUMNS - 1) * 0.5, 1.0, 9.0), Vector3(GAP * (COLUMNS - 1) * 0.5, 1.0, 0.0))
	_phase += 1
	if _phase % (SETTLE_FRAMES + 1) == 1:
		if _jobs.is_empty():
			_write_sheets()
			quit(0)
			return
		_pose(_jobs[0])
	elif _phase % (SETTLE_FRAMES + 1) == 0:
		var job: Array = _jobs.pop_front()
		(_strips.get_or_add(job[0], []) as Array).append(root.get_texture().get_image())


func _pose(job: Array) -> void:
	for v: FighterView in _views:
		v.queue_free()
	_views.clear()
	var sheet := String(job[0])
	var kind := int(job[1])
	var character := "barbarian" if sheet == "grab" or sheet == "getup" else sheet
	var samples := _samples(character, kind)
	for i: int in samples.size():
		var view := FighterView.new()
		root.add_child(view)
		view.setup(i, _config, character)
		view.set_identity_visible(false)
		_drive(view, samples[i])
		_views.append(view)


## One view dictionary per column (the swing at six moments, or a holder and its victim).
func _samples(character: String, kind: int) -> Array[Dictionary]:
	var w := World.new(_config, 1, 1, null, [character] as Array[String])
	var base: Dictionary = w.state_view()["fighters"][0]
	base["facing"] = Vector3.RIGHT
	var out: Array[Dictionary] = []
	if kind == GETUP:
		return _getup_samples(base)
	if kind == TUMBLE:
		var flips: Array[Dictionary] = []
		for col: int in COLUMNS:
			var v := base.duplicate()
			v["state"] = Fighter.State.HITSTUN
			v["on_ground"] = false
			v["tumbling"] = true
			v["pos"] = Vector3(GAP * col, 0, 0)
			v["frames"] = col * 2
			flips.append(v)
		return flips
	if kind < 0:
		for col: int in [1, 2]:
			var v := base.duplicate()
			v["state"] = Fighter.State.HOLDING if col == 1 else Fighter.State.HELD
			v["facing"] = Vector3.RIGHT if col == 1 else Vector3.LEFT
			v["pos"] = Vector3(GAP + (0.0 if col == 1 else _config.grab_hold_distance), 0, 0)
			out.append(v)
		return out
	var frames := _frames(String(base["style"]), String(base["special"]), kind)
	var s := frames.startup_ticks
	var a := frames.active_ticks
	var r := frames.recovery_ticks
	for t: int in [1, maxi(s / 2, 1), s + 1, s + a, s + a + r / 2, s + a + r]:
		var v := base.duplicate()
		v["state"] = Fighter.State.SPECIAL if kind == K.SPECIAL else Fighter.State.ATTACK
		v["attack_kind"] = kind
		v["attack_ticks"] = t
		v["pos"] = Vector3(GAP * out.size(), 0, 0)
		out.append(v)
	return out


func _getup_samples(base: Dictionary) -> Array[Dictionary]:
	var a := Getup.attack_of(_config)
	var out: Array[Dictionary] = []
	for t: int in [1, a.startup_ticks / 2, a.startup_ticks + 1, a.startup_ticks + a.active_ticks,
			a.startup_ticks + a.active_ticks + a.recovery_ticks / 2, a.total_ticks()]:
		var v := base.duplicate()
		v["state"] = Fighter.State.GETUP
		v["getup"] = "attack"
		v["getup_ticks"] = t
		v["pos"] = Vector3(GAP * out.size(), 0, 0)
		out.append(v)
	return out


func _frames(style: String, special: String, kind: int) -> AttackData:
	if kind == K.SPECIAL:
		return SpecialCatalog.attack(special, _config)
	return StyleCatalog.build(style, _config).attacks.get_attack(kind)


func _drive(view: FighterView, v: Dictionary) -> void:
	view.apply(v, v, 1.0, 0)
	var swinging := int(v["state"]) in [Fighter.State.ATTACK, Fighter.State.SPECIAL, Fighter.State.GETUP]
	var start := v.duplicate()
	start["attack_ticks"] = 1
	start["getup_ticks"] = 1
	for i: int in 6:
		view.apply(v, v, 1.0, 0)  # the gear settles into its swing grip over a few frames
		view.animate(start if swinging else v, 0.05)
	for i: int in 2:
		view.animate(v, 0.0)
	for i: int in int(v.get("frames", 0)):
		view.animate(v, 1.0 / 30.0)


func _write_sheets() -> void:
	for sheet: String in _strips:
		var strips: Array = _strips[sheet]
		var first := strips[0] as Image
		var out := Image.create(first.get_width(), first.get_height() * strips.size(), false, first.get_format())
		for i: int in strips.size():
			out.blit_rect(strips[i], Rect2i(Vector2i.ZERO, first.get_size()), Vector2i(0, first.get_height() * i))
		var path := "%s/swings-%s.png" % [_out, sheet]
		out.save_png(path)
		print("capture: saved %s" % path)
