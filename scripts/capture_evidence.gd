extends SceneTree
## Automated visual-evidence capture (Phase 0 controller amendment, Ruling 3).
## Instantiates a scene, optionally tweaks GameConfig / toggles the debug panel,
## waits N rendered frames, then saves a screenshot of the viewport to disk.
##
## Usage (windowed, NOT headless -- it needs a renderer):
##   godot --path . -s res://scripts/capture_evidence.gd -- \
##       --scene=res://src/main/main.tscn --out=/abs/path/file.png \
##       [--frames=120] [--arena-radius=20] [--show-panel] [--show-touch] [--touch-layout=N] [--look=N] [--quality=N]

const DEFAULT_FRAMES := 120

var _frames_left: int = DEFAULT_FRAMES
var _out_path: String = ""


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())

	var scene_path: String = args.get("scene", "")
	_out_path = args.get("out", "")
	if scene_path.is_empty() or _out_path.is_empty():
		push_error("capture_evidence: usage: -- --scene=res://path.tscn --out=/abs/path.png [--frames=120] [--arena-radius=F] [--show-panel] [--show-touch] [--touch-layout=N] [--look=N] [--quality=N]")
		quit(1)
		return

	_frames_left = int(args.get("frames", str(DEFAULT_FRAMES)))

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("capture_evidence: failed to load scene %s" % scene_path)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame

	if args.has("arena-radius"):
		var radius := float(args["arena-radius"])
		var config := load("res://src/config/default_config.tres") as GameConfig
		if config == null:
			push_error("capture_evidence: GameConfig missing at res://src/config/default_config.tres")
			quit(1)
			return
		config.arena_radius = radius
		config.emit_changed()

	if args.has("touch-layout"):
		var config := load("res://src/config/default_config.tres") as GameConfig
		if config == null:
			push_error("capture_evidence: GameConfig missing at res://src/config/default_config.tres")
			quit(1)
			return
		config.touch_layout = int(args["touch-layout"])
		config.emit_changed()

	if args.has("look"):
		var look_config := load("res://src/config/default_config.tres") as GameConfig
		if look_config == null:
			push_error("capture_evidence: GameConfig missing at res://src/config/default_config.tres")
			quit(1)
			return
		look_config.look_preset = int(args["look"])
		look_config.emit_changed()
		LookPreset.apply(look_config.look_preset)

	if args.has("quality"):
		var quality_config := load("res://src/config/default_config.tres") as GameConfig
		if quality_config == null:
			push_error("capture_evidence: GameConfig missing at res://src/config/default_config.tres")
			quit(1)
			return
		quality_config.quality_level = int(args["quality"])
		quality_config.emit_changed()

	if args.has("show-panel"):
		var panel := _find_config_panel(instance)
		if panel == null:
			push_error("capture_evidence: no ConfigPanel found in scene tree")
			quit(1)
			return
		panel.toggle()

	if args.has("show-touch"):
		var touch := _find_touch_input(instance)
		if touch == null:
			push_error("capture_evidence: no TouchInput found in scene tree")
			quit(1)
			return
		touch.visible = true

	process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	var image := root.get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		push_error("capture_evidence: failed to save PNG to %s (error %d)" % [_out_path, err])
		quit(1)
		return
	print("capture_evidence: saved %s" % _out_path)
	quit(0)


func _find_config_panel(node: Node) -> ConfigPanel:
	if node is ConfigPanel:
		return node
	for child: Node in node.get_children():
		var found := _find_config_panel(child)
		if found != null:
			return found
	return null


func _find_touch_input(node: Node) -> TouchInput:
	if node is TouchInput:
		return node
	for child: Node in node.get_children():
		var found := _find_touch_input(child)
		if found != null:
			return found
	return null


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in raw:
		if arg.begins_with("--"):
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq >= 0:
				out[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				out[body] = true
	return out
