extends SceneTree
## Renders the app icon (the CrestLogo on a canopy rounded square) to a PNG. It is
## `application/config/icon`, so the Web export derives the favicon and apple-touch-icon from it and
## desktop builds use it as the window icon. Windowed run (needs a renderer):
##   godot --path . -s res://scripts/export_app_icon.gd -- [--size=1024] [--out=res://assets/branding/app-icon.png]

const DEFAULT_SIZE := 1024
const DEFAULT_OUT := "res://assets/branding/app-icon.png"
## Corner radius and crest size as fractions of the icon edge.
const CORNER := 0.22
const CREST_SCALE := 0.78
const CORNER_DETAIL := 16
## Frames to let the SubViewport draw before reading it back.
const SETTLE_FRAMES := 3

var _viewport: SubViewport
var _out: String = ""
var _frames: int = SETTLE_FRAMES


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	var px := int(args.get("size", str(DEFAULT_SIZE)))
	_out = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(px, px)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_viewport.add_child(_tile(float(px)))
	process_frame.connect(_on_frame)


func _tile(px: float) -> Control:
	var tile := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DS.CANOPY
	style.set_corner_radius_all(int(px * CORNER))
	style.corner_detail = CORNER_DETAIL
	style.anti_aliasing = true
	tile.add_theme_stylebox_override("panel", style)
	tile.size = Vector2(px, px)
	var crest_px := px * CREST_SCALE
	var crest := CrestLogo.new(crest_px)
	crest.size = Vector2(crest_px, crest_px)
	crest.position = Vector2.ONE * (px - crest_px) / 2.0
	tile.add_child(crest)
	return tile


func _on_frame() -> void:
	_frames -= 1
	if _frames > 0:
		return
	var err := _viewport.get_texture().get_image().save_png(_out)
	if err != OK:
		push_error("export_app_icon: cannot save %s (%s)" % [_out, error_string(err)])
		quit(1)
		return
	print("export_app_icon: saved %s" % _out)
	quit(0)
