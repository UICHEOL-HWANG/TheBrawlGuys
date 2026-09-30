class_name SfxSynth
extends RefCounted
## Tiny sfxr-style synthesizer (context F9): one oscillator (square/saw/sine/triangle/noise) with
## an exponential-curve pitch sweep, vibrato, noise mix, one-pole lowpass and an ADSR-ish
## envelope, peak-normalized to `volume`. Deterministic: noise uses a seeded generator.
## Used offline by scripts/bake_sfx.gd and the music sequencer; nothing synthesizes at runtime.

const SAMPLE_RATE := 44100
const DEFAULTS := {
	"wave": "square", "freq_start": 440.0, "freq_end": 440.0, "freq_curve": 1.0,
	"attack": 0.005, "sustain": 0.08, "decay": 0.12, "sustain_level": 0.7,
	"vibrato_depth": 0.0, "vibrato_hz": 6.0, "duty": 0.5, "noise_mix": 0.0,
	"lowpass": 1.0, "volume": 0.8, "seed": 1,
}


static func render(params: Dictionary) -> PackedFloat32Array:
	var p := DEFAULTS.duplicate()
	p.merge(params, true)
	var attack := float(p["attack"])
	var sustain := float(p["sustain"])
	var decay := float(p["decay"])
	var total := maxi(roundi((attack + sustain + decay) * SAMPLE_RATE), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"])
	var out := PackedFloat32Array()
	out.resize(total)
	var phase := 0.0
	var low := 0.0
	var cutoff := clampf(float(p["lowpass"]), 0.001, 1.0)
	for i: int in total:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / total
		var f := lerpf(float(p["freq_start"]), float(p["freq_end"]), pow(progress, float(p["freq_curve"])))
		f *= 1.0 + float(p["vibrato_depth"]) * sin(TAU * float(p["vibrato_hz"]) * t)
		phase = fmod(phase + f / SAMPLE_RATE, 1.0)
		var v := _osc(String(p["wave"]), phase, float(p["duty"]), rng)
		v = lerpf(v, rng.randf_range(-1.0, 1.0), float(p["noise_mix"]))
		low += (v - low) * cutoff
		out[i] = low * _envelope(t, attack, sustain, decay, float(p["sustain_level"]))
	var pk := peak(out)
	if pk > 0.0:
		var gain := float(p["volume"]) / pk
		for i: int in total:
			out[i] *= gain
	return out


static func peak(samples: PackedFloat32Array) -> float:
	var m := 0.0
	for s: float in samples:
		m = maxf(m, absf(s))
	return m


static func _osc(wave: String, phase: float, duty: float, rng: RandomNumberGenerator) -> float:
	match wave:
		"saw":
			return phase * 2.0 - 1.0
		"sine":
			return sin(TAU * phase)
		"triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
		"noise":
			return rng.randf_range(-1.0, 1.0)
	return 1.0 if phase < duty else -1.0


static func _envelope(t: float, attack: float, sustain: float, decay: float, level: float) -> float:
	if t < attack:
		return t / attack
	if t < attack + sustain:
		return lerpf(1.0, level, (t - attack) / maxf(sustain, 0.0001))
	return level * maxf(1.0 - (t - attack - sustain) / maxf(decay, 0.0001), 0.0)
