extends SceneTree
## Phase 5 T8 evidence (design.md DS-VIS-02, direction A): the style gear in a real match frame
## (MatchStage + CameraRig on the default arena, sim running one tick per frame). The four
## characters are forced per slot (slot models: 0 Knight, 1 Barbarian, 2 Mage, 3 Rogue) until
## character select (T9) wires the chosen character into the match; they stand close together
## (a crowded fight) and the Barbarian carries a bat, so its gloves step aside for the item.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_gear_match.gd -- \
##       --out-dir=/abs/dir
## Writes <out-dir>/silhouette-final-match.png and a 3x crop silhouette-final-match-zoom.png.

const DT := 1.0 / 60.0
const SEED := 7
const SHOT_FRAME := 240  # the camera has settled on the cluster
const FACING := Vector3(0.24, 0.0, 0.97)  # roughly toward the camera
const CHARACTERS: Array[String] = ["knight", "barbarian", "mage", "rogue"]
const SPOTS: Array[Vector3] = [Vector3(-1.1, 0, 0.3), Vector3(0.1, 0, -0.5), Vector3(1.2, 0, 0.2), Vector3(0.0, 0, 1.2)]
const BAT_SLOT := 1
const ZOOM := 3
const ZOOM_SHIFT := Vector2i(0, -40)  # the cluster sits a little above the screen centre

var _out: String = ""
var _frame: int = 0
var _config := GameConfig.new()
var _world: World
var _stage: MatchStage
var _camera: CameraRig
var _prev: Dictionary = {}
var _curr: Dictionary = {}


func _init() -> void:
	_out = String(CaptureArgs.parse(OS.get_cmdline_user_args()).get("out-dir", ""))
	if _out.is_empty():
		push_error("capture_gear_match: usage: -- --out-dir=/abs/dir")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _world == null:
		_build()  # root enters the tree after _init
		return
	_step()
	_frame += 1
	if _frame == SHOT_FRAME:
		CaptureArgs.save(root, "%s/silhouette-final-match.png" % _out)
		_save_zoom("%s/silhouette-final-match-zoom.png" % _out)
		quit(0)


## The same frame cropped around the screen centre (the cluster) and scaled up, nearest filter.
func _save_zoom(path: String) -> void:
	var img := root.get_texture().get_image()
	var size := img.get_size() / ZOOM
	var crop := img.get_region(Rect2i(img.get_size() / 2 - size / 2 + ZOOM_SHIFT, size))
	crop.resize(size.x * ZOOM, size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	var err := crop.save_png(path)
	if err != OK:
		push_error("capture_gear_match: cannot save %s (%s)" % [path, error_string(err)])
		return
	print("capture: saved %s" % path)


func _build() -> void:
	_world = World.new(_config, SEED, CHARACTERS.size(), null, CHARACTERS)
	for i: int in CHARACTERS.size():
		_world.fighters[i].pos = SPOTS[i]
		_world.fighters[i].facing = FACING.normalized()
	_world.fighters[BAT_SLOT].item_kind = Item.Kind.BAT
	_world.fighters[BAT_SLOT].item_uses = _config.bat_uses
	_stage = MatchStage.new()
	root.add_child(_stage)
	_stage.setup(_config, SEED, CHARACTERS.size())
	_camera = CameraRig.new()
	root.add_child(_camera)
	_camera.setup(_config)
	_curr = _world.state_view()
	_prev = _curr


func _step() -> void:
	var inputs: Array[InputFrame] = []
	for i: int in CHARACTERS.size():
		inputs.append(InputFrame.neutral())
	_prev = _curr
	_world.tick(inputs)
	_curr = _world.state_view()
	_stage.draw(_prev, _curr, 1.0, DT)
	_camera.follow(CameraFraming.match_targets(_curr, _config), DT)
