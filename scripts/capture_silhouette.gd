extends SceneTree
## Phase 5 T8 evidence (design.md DS-VIS-02 gate): the four characters side by side for the
## current look (base) and each mockup direction A / B / C (StyleMockup), in three versions:
##   silhouette-<dir>.png      normal in-game render (soft toon, sun, grass)
##   silhouette-<dir>-bw.png   the same frame in grayscale (luma)
##   silhouette-<dir>-sil.png  flat canopy_deep fill on cream: shape only, no color, no shading
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_silhouette.gd -- \
##       --out-dir=/abs/dir
## Optional: --only=A (one direction).

const SETTLE_FRAMES := 12
const SPACING := 1.8
const FACING := Vector3(0.35, 0.0, 1.0)
const LABEL_Z := 0.75
const CAM_FROM := Vector3(0.0, 2.0, 7.2)
const CAM_TO := Vector3(0.0, 1.05, 0.0)
const CAM_FOV := 38.0
const LABEL_PIXEL := 0.0042
const DIRS := {"base": StyleMockup.Direction.BASE, "A": StyleMockup.Direction.A,
	"B": StyleMockup.Direction.B, "C": StyleMockup.Direction.C}

var _out: String = ""
var _steps: Array[Dictionary] = []
var _frame: int = 0
var _stage: Node3D = null
var _config := GameConfig.new()


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	if _out.is_empty():
		push_error("capture_silhouette: usage: -- --out-dir=/abs/dir [--only=A]")
		quit(1)
		return
	var only := String(args.get("only", ""))
	for key: String in DIRS:
		if only.is_empty() or only == key:
			_steps.append({"key": key, "sil": false})
			_steps.append({"key": key, "sil": true})
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _stage == null:
		_next()  # root enters the tree after _init: build the first stage on the first frame
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	var step: Dictionary = _steps.pop_front()
	var base := "%s/silhouette-%s" % [_out, step["key"]]
	if bool(step["sil"]):
		CaptureArgs.save(root, base + "-sil.png")
	else:
		CaptureArgs.save(root, base + ".png")
		_save_gray(base + "-bw.png")
	if _steps.is_empty():
		quit(0)
		return
	_next()


func _next() -> void:
	if _stage != null:
		_stage.queue_free()
	_frame = 0
	var step: Dictionary = _steps[0]
	var sil := bool(step["sil"])
	_stage = _plain_stage() if sil else CaptureArgs.grass_stage(root)
	var lineup := _lineup(int(DIRS[step["key"]]))
	if sil:
		StyleMockup.silhouette(lineup, DS.CANOPY_DEEP)
	CaptureArgs.camera(_stage, CAM_FROM, CAM_TO, CAM_FOV)


func _lineup(direction: int) -> Node3D:
	var lineup := Node3D.new()
	_stage.add_child(lineup)
	var count := StyleMockup.LINEUP.size()
	for n: int in count:
		var slot := StyleMockup.LINEUP[n]
		var character := String(CharacterCatalog.for_player(slot)["name"])
		var v := FighterView.new()
		lineup.add_child(v)
		v.setup(slot, _config)
		v.set_identity_visible(false)
		v.set_blob_shadow(false)
		var d := _idle_view(slot, Vector3((n - (count - 1) * 0.5) * SPACING, 0.0, 0.0))
		v.apply(d, d, 1.0, 0)
		StyleMockup.apply(direction, v, character)
		_stage.add_child(_label(character, v.position))
	return lineup


func _label(character: String, at: Vector3) -> Label3D:
	var style := StyleMockup.style_of(character)
	var label := Label3D.new()
	label.text = "%s\n%s · %s" % [character, StyleMockup.STYLE_NAME[style], StyleMockup.SPECIAL_NAME[character]]
	label.font = load(DS.FONT_DISPLAY_PATH) as Font
	label.font_size = DS.SIZE_TITLE
	label.pixel_size = LABEL_PIXEL
	label.modulate = DS.CANOPY_DEEP
	label.outline_modulate = DS.UI_SURFACE
	label.outline_size = DS.TEXT_OUTLINE * 3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at + Vector3(0.0, 0.05, LABEL_Z)
	return label


## Cream background, no lights, no ground: for the flat silhouette shots.
func _plain_stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DS.UI_SURFACE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	return stage


## Grayscale copy of the current frame (luma per pixel).
func _save_gray(path: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			c.r = l
			c.g = l
			c.b = l
			img.set_pixel(x, y, c)
	var err := img.save_png(path)
	if err != OK:
		push_error("capture_silhouette: cannot save %s (%s)" % [path, error_string(err)])
		return
	print("capture: saved %s" % path)


func _idle_view(i: int, pos: Vector3) -> Dictionary:
	return {"id": i, "spawn_id": 0, "pos": pos, "facing": FACING.normalized(),
		"state": Fighter.State.IDLE, "on_ground": true, "invuln_ticks": 0, "item_kind": Fighter.NONE,
		"item_uses": 0, "attack_kind": -1, "charge_ticks": 0, "hitstop_ticks": 0}
