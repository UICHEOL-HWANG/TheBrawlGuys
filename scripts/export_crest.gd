extends SceneTree
## Renders the CrestLogo (design.md DS-CMP-15) — emblem only, no text — to a transparent PNG for
## app icons and favicons. Windowed run (needs a renderer):
##   godot --path . -s res://scripts/export_crest.gd -- [--size=1024] [--out=res://assets/branding/crest-1024.png]

const DEFAULT_SIZE := 1024
const DEFAULT_OUT := "res://assets/branding/crest-1024.png"
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
	var px := int(args.get("size", str(DEFAULT_SIZE)))
	_out = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(px, px)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var crest := CrestLogo.new(float(px))
	crest.size = Vector2(px, px)
	_viewport.add_child(crest)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames -= 1
	if _frames > 0:
		return
	var err := _viewport.get_texture().get_image().save_png(_out)
	if err != OK:
		push_error("export_crest: cannot save %s (%s)" % [_out, error_string(err)])
		quit(1)
		return
	print("export_crest: saved %s" % _out)
	quit(0)
