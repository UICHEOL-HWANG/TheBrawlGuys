extends GutTest
## Placeholder BGM and the music director (design.md DS-SFX-02, context F10).


func test_layers_share_length_and_tempo() -> void:
	var base: Dictionary = MusicSequencer.SONGS["battle_base"]
	var intense: Dictionary = MusicSequencer.SONGS["battle_intense"]
	assert_eq(base["bpm"], intense["bpm"])
	assert_eq(MusicSequencer.length_samples(base), MusicSequencer.length_samples(intense), "layers stay in sync")
	assert_eq(MusicSequencer.render(base).size(), MusicSequencer.length_samples(base))


func test_render_is_deterministic_and_audible() -> void:
	var song: Dictionary = MusicSequencer.SONGS["menu"]
	var a := MusicSequencer.render(song)
	assert_eq(a, MusicSequencer.render(song))
	assert_gt(SfxSynth.peak(a), 0.1)
	assert_lte(SfxSynth.peak(a), 1.0)


func test_battle_layers_never_clip_when_summed() -> void:
	var pair := MusicSequencer.render_pair(MusicSequencer.SONGS["battle_base"], MusicSequencer.SONGS["battle_intense"])
	assert_eq(pair.size(), 2)
	assert_eq(pair[0].size(), pair[1].size())
	var sum := PackedFloat32Array()
	sum.resize(pair[0].size())
	for i: int in sum.size():
		sum[i] = pair[0][i] + pair[1][i]
	assert_lte(SfxSynth.peak(sum), MusicSequencer.MASTER_PEAK + 1e-4, "base + intense stays under the master peak")
	assert_gt(SfxSynth.peak(pair[1]), 0.05, "the intense layer is still audible")


func test_midi_to_hz() -> void:
	assert_almost_eq(MusicSequencer.midi_to_hz(69), 440.0, 0.001)
	assert_almost_eq(MusicSequencer.midi_to_hz(81), 880.0, 0.001)


func test_intensity_rule() -> void:
	var v := {"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 3}, {"state": Fighter.State.IDLE, "stocks": 2}]}
	assert_false(MusicDirector.wants_intense(v))
	(v["fighters"][1] as Dictionary)["stocks"] = 1
	assert_true(MusicDirector.wants_intense(v))
	v["match_over"] = true
	assert_false(MusicDirector.wants_intense(v), "no intensity after the result")


func test_files_are_baked_and_director_switches_layers() -> void:
	for name: String in ["battle_base", "battle_intense", "menu"]:
		assert_true(ResourceLoader.exists(MusicDirector.path_for(name)), "%s baked (run scripts/bake_music.gd)" % name)
	var d := MusicDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	d.play_battle()
	assert_eq(d.intense_target_db(), MusicDirector.SILENT_DB)
	d.update_from({"match_over": false, "fighters": [{"state": Fighter.State.IDLE, "stocks": 1}]})
	assert_true(d.is_intense())
	assert_eq(d.intense_target_db(), 0.0)


## Two plain players (Web Audio samples on the web build), never an AudioStreamSynchronized,
## which the single-threaded web build mixes in the engine and stutters.
func test_battle_plays_base_and_silent_layer_on_two_plain_players() -> void:
	var d := MusicDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	d.play_battle()
	for p: AudioStreamPlayer in [d.base_player(), d.layer_player()]:
		assert_false(p.stream is AudioStreamSynchronized)
		assert_eq(p.bus, AudioBuses.MUSIC)
		assert_true(p.playing)
	assert_eq(d.layer_player().volume_db, MusicDirector.SILENT_DB, "the layer waits silently, on the beat")
	d.play_menu()
	assert_false(d.layer_player().playing, "the menu loop plays alone")
	assert_true(d.base_player().playing)


func test_the_battle_theme_loads_the_designed_ogg_loops() -> void:
	for name: String in ["battle_base", "battle_intense"]:
		assert_eq(MusicDirector.path_for(name), "res://assets/music/%s.ogg" % name, "scripts/music/compose.py output wins")
	var base: AudioStream = load(MusicDirector.path_for("battle_base"))
	var layer: AudioStream = load(MusicDirector.path_for("battle_intense"))
	assert_almost_eq(base.get_length(), layer.get_length(), 0.01, "the layers play in sync, so they share one length")
