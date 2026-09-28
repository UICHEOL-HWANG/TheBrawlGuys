extends SceneTree
## Regenerates res://src/ui/theme/forest_theme.tres from DS tokens.
## Run: godot --headless --path . -s res://scripts/build_theme.gd

const OUT_PATH := "res://src/ui/theme/forest_theme.tres"


func _init() -> void:
	var err := ResourceSaver.save(ThemeBuilder.build(), OUT_PATH)
	if err != OK:
		push_error("build_theme: save failed (%s)" % error_string(err))
		quit(1)
		return
	print("build_theme: saved %s" % OUT_PATH)
	quit(0)
