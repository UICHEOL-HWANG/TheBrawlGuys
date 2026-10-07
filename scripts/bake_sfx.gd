extends SceneTree
## Renders every SfxRecipes entry into assets/sfx/<name>.wav (context F9). Re-run after editing
## a recipe. Run: godot --headless --path . -s res://scripts/bake_sfx.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sfx"))
	for name: String in SfxRecipes.RECIPES:
		var stream := WavWriter.to_stream(SfxSynth.render(SfxRecipes.RECIPES[name]), SfxSynth.SAMPLE_RATE)
		var err := stream.save_to_wav(ProjectSettings.globalize_path(SfxRecipes.path(name)))
		if err != OK:
			push_error("bake_sfx: %s failed (%s)" % [name, error_string(err)])
			quit(1)
			return
	print("bake_sfx: wrote %d sounds" % baked)
	quit(0)
