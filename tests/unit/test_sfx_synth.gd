extends GutTest
## Offline SFX synthesis (context F9): deterministic, exact length, peak-normalized, and every
## recipe baked into assets/sfx.


func _zero_crossings(s: PackedFloat32Array, from: int, to: int) -> int:
	var n := 0
	for i: int in range(from + 1, to):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n


func test_length_follows_the_envelope() -> void:
	var s := SfxSynth.render({"attack": 0.01, "sustain": 0.05, "decay": 0.04})
	assert_eq(s.size(), roundi(0.1 * SfxSynth.SAMPLE_RATE))


func test_deterministic_including_noise() -> void:
	var p := {"wave": "noise", "sustain": 0.1, "seed": 7}
	assert_eq(SfxSynth.render(p), SfxSynth.render(p))
	var q := p.duplicate()
	q["seed"] = 8
	assert_ne(SfxSynth.render(p), SfxSynth.render(q))


func test_peak_is_normalized_to_volume() -> void:
	var s := SfxSynth.render({"wave": "square", "sustain": 0.1, "volume": 0.6})
	assert_almost_eq(SfxSynth.peak(s), 0.6, 0.01)


func test_frequency_sweep_direction() -> void:
	var s := SfxSynth.render({"wave": "sine", "freq_start": 800.0, "freq_end": 200.0, "sustain": 0.4, "attack": 0.0, "decay": 0.0})
	var q := s.size() / 4
	assert_gt(_zero_crossings(s, 0, q), _zero_crossings(s, s.size() - q, s.size()), "falling pitch")


func test_wav_stream_format() -> void:
	var stream := WavWriter.to_stream(PackedFloat32Array([0.0, 1.0, -1.0, 2.0]), SfxSynth.SAMPLE_RATE)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(stream.stereo)
	assert_eq(stream.mix_rate, SfxSynth.SAMPLE_RATE)
	assert_eq(stream.data.size(), 8, "2 bytes per sample")
	assert_eq(stream.data.decode_s16(6), 32767, "clamped to full scale")


func test_every_recipe_is_audible_and_baked() -> void:
	for name: String in SfxRecipes.RECIPES:
		var s := SfxSynth.render(SfxRecipes.RECIPES[name])
		assert_gt(s.size(), 0, name)
		assert_gt(SfxSynth.peak(s), 0.05, "%s is audible" % name)
		assert_lte(SfxSynth.peak(s), 1.0, "%s does not clip" % name)
		assert_true(ResourceLoader.exists(SfxRecipes.path(name)), "%s baked (run scripts/bake_sfx.gd)" % name)
