extends SceneTree
## Renders the link-preview card (Open Graph / Twitter, 1200x630) served next to the web build:
## the four characters on the classic arena under a close camera, with the crest, title and tagline
## on a canopy_deep fade at the left. deploy/web_shell.html points og:image at it and
## scripts/deploy_web.sh copies it into the build.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1200x630 --always-on-top -s res://scripts/capture_share_card.gd -- \
##       [--out=res://deploy/share/og-image.png]

const DEFAULT_OUT := "res://deploy/share/og-image.png"
const CARD := Vector2i(1200, 630)
const DT := 1.0 / 60.0
const SEED := 7
const SETTLE_FRAMES := 40
## Frames before the shot at which slots 1 and 3 swing, so the shot lands mid-attack.
const SWING_LEAD := 8
## Fighters stand to the right of the frame; the text panel covers the left.
const SPOTS: Array[Vector3] = [
	Vector3(3.0, 0, 0.3), Vector3(3.95, 0, -0.35), Vector3(4.85, 0, 0.35), Vector3(5.8, 0, -0.3),
]
const FACINGS: Array[Vector3] = [
	Vector3(0.9, 0, 1), Vector3(-0.3, 0, 1), Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 1),
]
const CAM_FROM := Vector3(2.2, 2.9, 5.8)
const CAM_TO := Vector3(2.2, 0.8, 0.0)
const CAM_FOV := 42.0
const CREST_SIZE := 150.0
const TITLE_SIZE := 76
const PANEL_LEFT := 56
## Fade stops (offset, alpha) of canopy_deep over the scene, left to right.
const FADE: Array[Vector2] = [Vector2(0.0, 0.96), Vector2(0.4, 0.88), Vector2(0.6, 0.0)]
const TAGLINE := "치고, 날리고, 끝까지 버티기"

var _out: String = ""
var _frame: int = 0
var _config := GameConfig.new()
var _world: World
var _stage: MatchStage
var _prev: Dictionary = {}
var _curr: Dictionary = {}


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	root.size = CARD
	process_frame.connect(_on_frame)


## Built on the first frame, once root is in the tree (character models measure their bounds).
func _build() -> void:
	var chars: Array[String] = []
	chars.assign(CharacterData.IDS)
	_world = World.new(_config, SEED, chars.size(), null, chars)
	for i: int in chars.size():
		_world.fighters[i].pos = SPOTS[i]
		_world.fighters[i].facing = FACINGS[i].normalized()
	_stage = MatchStage.new()
	root.add_child(_stage)
	_stage.setup(_config, SEED, chars.size())
	var rig := Node3D.new()
	root.add_child(rig)
	CaptureArgs.camera(rig, CAM_FROM, CAM_TO, CAM_FOV)
	root.add_child(_overlay())
	_curr = _world.state_view()
	_prev = _curr


func _on_frame() -> void:
	if _world == null:
		_build()
		return
	_step(_frame == SETTLE_FRAMES - SWING_LEAD)
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	quit(0 if CaptureArgs.save(root, _out) == OK else 1)


## One sim tick (slots 1 and 3 press light attack when swing), fighters pinned to their spots.
func _step(swing: bool) -> void:
	var inputs: Array[InputFrame] = []
	for i: int in SPOTS.size():
		var attack := swing and i % 2 == 1
		inputs.append(InputFrame.make(0, 0, false, attack) if attack else InputFrame.neutral())
	_prev = _curr
	_world.tick(inputs)
	for i: int in SPOTS.size():
		_world.fighters[i].pos = SPOTS[i]
		_world.fighters[i].facing = FACINGS[i].normalized()
	_curr = _world.state_view()
	_stage.draw(_prev, _curr, 1.0, DT)


func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	var fade := TextureRect.new()
	fade.texture = _fade_texture()
	fade.size = Vector2(CARD)
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(fade)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S3)
	col.position = Vector2(PANEL_LEFT, 0)
	col.size = Vector2(CARD.x * 0.5, CARD.y)
	layer.add_child(col)
	var crest := CrestLogo.new(CREST_SIZE)
	crest.custom_minimum_size = Vector2(CREST_SIZE, CREST_SIZE)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(crest)
	var title := LoginLayout.title_label(LoginText.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	col.add_child(title)
	var tag := LoginLayout.caption(true)
	tag.text = TAGLINE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.add_theme_color_override("font_color", DS.GRASS)
	col.add_child(tag)
	return layer


func _fade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(FADE.map(func(s: Vector2) -> float: return s.x))
	g.colors = PackedColorArray(FADE.map(func(s: Vector2) -> Color:
		return Color(DS.CANOPY_DEEP, s.y)))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = CARD.x
	tex.height = 1
	return tex
