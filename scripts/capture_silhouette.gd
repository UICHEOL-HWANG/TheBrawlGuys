extends SceneTree
## Phase 5 T8 evidence (design.md DS-VIS-02, direction A approved): the four characters side by
## side in the real game look (FighterView + StyleGear driven by sim views that carry each
## character), animated in their style idle:
##   silhouette-final.png        normal in-game render (soft toon, sun, grass)
##   silhouette-final-bw.png     the same frame in grayscale (luma)
##   silhouette-final-sil.png    flat canopy_deep fill on cream: shape only
##   silhouette-final-held.png   everyone holding a bat: the hand gear steps aside for the item
## Characters are forced per slot (slot models: 0 Knight, 1 Barbarian, 2 Mage, 3 Rogue) until
## character select (T9) wires the chosen character into the match.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_silhouette.gd -- \
##       --out-dir=/abs/dir

const SETTLE_FRAMES := 20
const DT := 1.0 / 60.0
const SPACING := 1.8
const FACING := Vector3(0.35, 0.0, 1.0)
const LABEL_Z := 0.75
const CAM_FROM := Vector3(0.0, 2.0, 7.2)
const CAM_TO := Vector3(0.0, 1.05, 0.0)
const CAM_FOV := 38.0
const LABEL_PIXEL := 0.0042
const SLOT_CHARACTERS: Array[String] = ["knight", "barbarian", "mage", "rogue"]
## Lineup order: boxing, boxing, weapon, ranged (slot indices).
const LINEUP: Array[int] = [1, 3, 0, 2]
const STYLE_NAME := {StyleCatalog.BOXER: "권투", StyleCatalog.WEAPON: "무기", StyleCatalog.RANGED: "원거리"}
const SPECIAL_NAME := {"barbarian": "대지 강타", "rogue": "돌진 연타", "knight": "회전 베기", "mage": "거대 화염구"}
const STEPS: Array[Dictionary] = [
	{"file": "final", "sil": false, "held": false, "gray": true},
	{"file": "final-sil", "sil": true, "held": false, "gray": false},
	{"file": "final-held", "sil": false, "held": true, "gray": false},
]

var _out: String = ""
var _steps: Array[Dictionary] = []
var _frame: int = 0
var _stage: Node3D = null
var _views: Array[FighterView] = []
var _data: Array[Dictionary] = []
var _config := GameConfig.new()


func _init() -> void:
	_out = String(CaptureArgs.parse(OS.get_cmdline_user_args()).get("out-dir", ""))
	if _out.is_empty():
		push_error("capture_silhouette: usage: -- --out-dir=/abs/dir")
		quit(1)
		return
	_steps = STEPS.duplicate()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _stage == null:
		_next()  # root enters the tree after _init: build the first stage on the first frame
		return
	for n: int in _views.size():
		_views[n].animate(_data[n], DT)
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	var step: Dictionary = _steps.pop_front()
	var base := "%s/silhouette-%s" % [_out, step["file"]]
	CaptureArgs.save(root, base + ".png")
	if bool(step["gray"]):
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
	var lineup := _lineup(bool(step["held"]))
	if sil:
		_silhouette(lineup, DS.CANOPY_DEEP)
	CaptureArgs.camera(_stage, CAM_FROM, CAM_TO, CAM_FOV)


func _lineup(held: bool) -> Node3D:
	var lineup := Node3D.new()
	_stage.add_child(lineup)
	_views.clear()
	_data.clear()
	var world := World.new(_config, 0, SLOT_CHARACTERS.size(), null, SLOT_CHARACTERS)
	var all: Array = world.state_view()["fighters"]
	for n: int in LINEUP.size():
		var slot := LINEUP[n]
		var v := FighterView.new()
		lineup.add_child(v)
		v.setup(slot, _config)
		v.set_identity_visible(false)
		v.set_blob_shadow(false)
		var d := _pose((all[slot] as Dictionary), Vector3((n - (LINEUP.size() - 1) * 0.5) * SPACING, 0.0, 0.0), held)
		v.apply(d, d, 1.0, 0)
		_views.append(v)
		_data.append(d)
		_stage.add_child(_label(d, v.position))
	return lineup


func _pose(view: Dictionary, pos: Vector3, held: bool) -> Dictionary:
	var d := view.duplicate()
	d["pos"] = pos
	d["facing"] = FACING.normalized()
	d["item_kind"] = Item.Kind.BAT if held else Fighter.NONE
	d["item_uses"] = _config.bat_uses if held else 0
	return d


func _label(view: Dictionary, at: Vector3) -> Label3D:
	var character := String(view["character"])
	var label := Label3D.new()
	label.text = "%s\n%s · %s" % [character.capitalize(), STYLE_NAME[view["style"]], SPECIAL_NAME[character]]
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


## Cream background, no lights, no ground: for the flat silhouette shot.
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


## Flat unshaded material on every mesh under root (Label3D excluded): a pure silhouette.
func _silhouette(root_node: Node, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	for node: Node in root_node.find_children("*", "GeometryInstance3D", true, false):
		if node is Label3D:
			continue
		(node as GeometryInstance3D).material_override = mat
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Grayscale copy of the current frame (luma per pixel).
func _save_gray(path: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			img.set_pixel(x, y, Color(l, l, l))
	var err := img.save_png(path)
	if err != OK:
		push_error("capture_silhouette: cannot save %s (%s)" % [path, error_string(err)])
		return
	print("capture: saved %s" % path)
