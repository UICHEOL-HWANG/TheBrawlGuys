extends SceneTree
## Renders the placeholder BGM loops into assets/music/<name>.wav (context F10). The real
## soundtrack replaces these files (same names, .ogg allowed). Run:
## godot --headless --path . -s res://scripts/bake_music.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/music"))
	for name: String in MusicDirector.NAMES:
		var samples := MusicSequencer.render(MusicSequencer.SONGS[name])
		var path := ProjectSettings.globalize_path("res://assets/music/%s.wav" % name)
		var err := WavWriter.to_stream(samples, SfxSynth.SAMPLE_RATE).save_to_wav(path)
		if err != OK:
			push_error("bake_music: %s failed (%s)" % [name, error_string(err)])
			quit(1)
			return
	print("bake_music: wrote %d loops" % MusicDirector.NAMES.size())
	quit(0)
