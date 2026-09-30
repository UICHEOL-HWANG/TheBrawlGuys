class_name MusicSequencer
extends RefCounted
## Tiny offline sequencer for placeholder BGM (design.md DS-SFX-02, context F10): drum, bass and
## marimba-like voices rendered with SfxSynth, mixed and normalized. The patterns below are
## original to this project; the real soundtrack replaces the baked files with the same names.

## static var (not const): the drum patterns are built by _every().
static var SONGS: Dictionary = {
	"battle_base": {"bpm": 150.0, "bars": 8, "tracks": [
		{"instrument": "kick", "notes": _every(0.0, 1.0, 32)},
		{"instrument": "snare", "notes": _every(1.0, 2.0, 16)},
		{"instrument": "bass", "notes": [[0, 45, 0.5], [1.5, 45, 0.5], [2, 48, 0.5], [3, 50, 0.5], [4, 43, 0.5], [5.5, 43, 0.5], [6, 47, 0.5], [7, 50, 0.5],
			[8, 45, 0.5], [9.5, 45, 0.5], [10, 52, 0.5], [11, 50, 0.5], [12, 48, 0.5], [13.5, 47, 0.5], [14, 45, 0.5], [15, 43, 0.5]]},
		{"instrument": "marimba", "notes": [[0, 69, 0.5], [0.5, 72, 0.5], [1, 76, 0.5], [2, 74, 1.0], [3.5, 72, 0.5], [4, 67, 0.5], [4.5, 71, 0.5], [5, 74, 0.5],
			[6, 72, 1.0], [8, 69, 0.5], [8.5, 72, 0.5], [9, 76, 0.5], [10, 79, 1.0], [11.5, 76, 0.5], [12, 74, 0.5], [13, 72, 0.5], [14, 69, 1.5]]},
	]},
	"battle_intense": {"bpm": 150.0, "bars": 8, "tracks": [
		{"instrument": "hat", "notes": _every(0.0, 0.25, 128)},
		{"instrument": "clap", "notes": _every(1.0, 2.0, 16)},
		{"instrument": "whistle", "notes": [[0, 81, 1.0], [1, 79, 0.5], [1.5, 76, 0.5], [2, 79, 2.0], [4, 76, 1.0], [5, 74, 0.5], [5.5, 72, 0.5], [6, 74, 2.0],
			[8, 81, 1.0], [9, 83, 0.5], [9.5, 84, 0.5], [10, 83, 2.0], [12, 79, 1.0], [13, 76, 1.0], [14, 74, 2.0]]},
	]},
	"menu": {"bpm": 100.0, "bars": 8, "tracks": [
		{"instrument": "bass", "notes": [[0, 43, 2.0], [4, 45, 2.0], [8, 48, 2.0], [12, 47, 2.0]]},
		{"instrument": "marimba", "notes": [[0, 67, 1.0], [1, 71, 1.0], [2, 74, 2.0], [4, 69, 1.0], [5, 72, 1.0], [6, 76, 2.0],
			[8, 72, 1.0], [9, 76, 1.0], [10, 79, 2.0], [12, 71, 1.0], [13, 74, 1.0], [14, 78, 2.0]]},
	]},
}
## A written phrase covers 16 beats (4 bars); it repeats to fill the song.
const PHRASE_BEATS := 16.0
const MASTER_PEAK := 0.85


static func length_samples(song: Dictionary) -> int:
	return roundi(float(song["bars"]) * 4.0 * 60.0 / float(song["bpm"]) * SfxSynth.SAMPLE_RATE)


static func midi_to_hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


## One song normalized to MASTER_PEAK on its own.
static func render(song: Dictionary) -> PackedFloat32Array:
	var mix := _mix(song)
	_scale(mix, _gain_for(SfxSynth.peak(mix)))
	return mix


## Two layers that play together (battle base + intense) share ONE gain so their sum peaks at
## MASTER_PEAK instead of up to 2x that; the relative balance between the layers is kept.
static func render_pair(a: Dictionary, b: Dictionary) -> Array[PackedFloat32Array]:
	var mix_a := _mix(a)
	var mix_b := _mix(b)
	var summed := mix_a.duplicate()
	for i: int in mini(summed.size(), mix_b.size()):
		summed[i] += mix_b[i]
	var gain := _gain_for(SfxSynth.peak(summed))
	_scale(mix_a, gain)
	_scale(mix_b, gain)
	var out: Array[PackedFloat32Array] = [mix_a, mix_b]
	return out


static func _gain_for(peak: float) -> float:
	return MASTER_PEAK / peak if peak > 0.0 else 1.0


static func _scale(mix: PackedFloat32Array, gain: float) -> void:
	for i: int in mix.size():
		mix[i] *= gain


static func _mix(song: Dictionary) -> PackedFloat32Array:
	var total := length_samples(song)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var beat_samples := 60.0 / float(song["bpm"]) * SfxSynth.SAMPLE_RATE
	var song_beats := float(song["bars"]) * 4.0
	for track: Dictionary in song["tracks"]:
		for note: Array in track["notes"]:
			var repeat := 0.0
			while float(note[0]) + repeat < song_beats:
				var voice := SfxSynth.render(_voice(String(track["instrument"]), int(note[1]), float(note[2]) * 60.0 / float(song["bpm"])))
				var start := roundi((float(note[0]) + repeat) * beat_samples)
				for i: int in voice.size():
					var j := (start + i) % total  # wrap tails so the loop seam stays seamless
					mix[j] += voice[i]
				repeat += PHRASE_BEATS if String(track["instrument"]) in ["bass", "marimba", "whistle"] else song_beats
	return mix


static func _every(first: float, step: float, count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append([first + step * i, 0, 0.1])
	return out


static func _voice(instrument: String, midi: int, seconds: float) -> Dictionary:
	match instrument:
		"kick":
			return {"wave": "sine", "freq_start": 130.0, "freq_end": 45.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.04, "decay": 0.14, "volume": 0.9, "seed": 31}
		"snare":
			return {"wave": "noise", "attack": 0.002, "sustain": 0.03, "decay": 0.12, "lowpass": 0.55, "volume": 0.5, "seed": 32}
		"hat":
			return {"wave": "noise", "attack": 0.001, "sustain": 0.005, "decay": 0.04, "lowpass": 0.95, "volume": 0.2, "seed": 33}
		"clap":
			return {"wave": "noise", "attack": 0.003, "sustain": 0.02, "decay": 0.09, "lowpass": 0.7, "volume": 0.4, "seed": 34}
		"bass":
			return {"wave": "triangle", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.005, "sustain": seconds * 0.7, "decay": seconds * 0.3, "lowpass": 0.4, "volume": 0.6, "seed": 35}
		"whistle":
			return {"wave": "sine", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.02, "sustain": seconds * 0.8, "decay": seconds * 0.2, "vibrato_depth": 0.01, "vibrato_hz": 5.5, "volume": 0.35, "seed": 36}
	# marimba: bright sine with a fast decay
	return {"wave": "sine", "freq_start": midi_to_hz(midi), "freq_end": midi_to_hz(midi), "attack": 0.002, "sustain": 0.02, "decay": minf(seconds, 0.35), "volume": 0.45, "seed": 37}
