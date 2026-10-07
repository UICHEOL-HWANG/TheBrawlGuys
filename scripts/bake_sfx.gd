extends SceneTree
## Renders every SfxRecipes.all() entry (layered ones through SfxMix) into assets/sfx/<name>.wav
## (context F9), skipping HitSounds.NAMES (designed by scripts/music/hits.py). Re-run after
## editing a recipe. Run: godot --headless --path . -s res://scripts/bake_sfx.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sfx"))
	var recipes := SfxRecipes.all()
	var baked := 0
	for name: String in recipes:
		if HitSounds.NAMES.has(name):
			continue
		var stream := WavWriter.to_stream(SfxMix.render(recipes[name]), SfxSynth.SAMPLE_RATE)
		var err := stream.save_to_wav(ProjectSettings.globalize_path(SfxRecipes.path(name)))
		if err != OK:
			push_error("bake_sfx: %s failed (%s)" % [name, error_string(err)])
			quit(1)
			return
		baked += 1
	print("bake_sfx: wrote %d sounds" % baked)
	quit(0)
