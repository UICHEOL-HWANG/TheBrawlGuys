extends SceneTree
## Renders the boot splash (crest + game title) to a transparent PNG. Godot shows it on
## `application/boot_splash/bg_color` (canopy_deep) at startup, and the web shell
## (deploy/web_shell.html) shows the same image while the engine downloads, so the Godot logo never
## appears and the hand-off from page to engine is seamless. Windowed run (needs a renderer):
##   godot --path . -s res://scripts/export_boot_splash.gd -- [--out=res://assets/branding/boot-splash.png]

const DEFAULT_OUT := "res://assets/branding/boot-splash.png"
## 16:9 canvas; the engine and the web shell scale it to fit the window (keep aspect).
const CANVAS := Vector2i(1280, 720)
const CREST_SIZE := 200.0
const DISC_SIZE := 280.0
## Segments per rounded corner: enough for a smooth circle at this size.
const DISC_CORNER_DETAIL := 32
## Frames to let the SubViewport draw before reading it back.
const SETTLE_FRAMES := 3

var _viewport: SubViewport
var _out: String = ""
var _frames: int = SETTLE_FRAMES


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	_out = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	_viewport = SubViewport.new()
	_viewport.size = CANVAS
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_viewport.add_child(_content())
	process_frame.connect(_on_frame)


## Crest over the white Jua title, centered a little above the middle (the web shell puts its
## progress bar below).
func _content() -> Control:
	var center := CenterContainer.new()
	center.size = Vector2(CANVAS.x, CANVAS.y * 0.9)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S4)
	center.add_child(col)
	col.add_child(_medallion())
	col.add_child(LoginLayout.title_label("The Brawl Guys"))
	return center


## The crest's outer shield is canopy_deep like the splash background, so it sits on a lighter
## canopy disc to keep its outline.
func _medallion() -> Control:
	var disc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DS.CANOPY
	style.set_corner_radius_all(int(DISC_SIZE / 2.0))
	style.corner_detail = DISC_CORNER_DETAIL
	disc.add_theme_stylebox_override("panel", style)
	disc.custom_minimum_size = Vector2(DISC_SIZE, DISC_SIZE)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := CenterContainer.new()
	disc.add_child(holder)
	var crest := CrestLogo.new(CREST_SIZE)
	crest.custom_minimum_size = Vector2(CREST_SIZE, CREST_SIZE)
	holder.add_child(crest)
	return disc


func _on_frame() -> void:
	_frames -= 1
	if _frames > 0:
		return
	var err := _viewport.get_texture().get_image().save_png(_out)
	if err != OK:
		push_error("export_boot_splash: cannot save %s (%s)" % [_out, error_string(err)])
		quit(1)
		return
	print("export_boot_splash: saved %s" % _out)
	quit(0)
