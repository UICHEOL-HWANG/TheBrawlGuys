class_name CombatSfxRecipes
extends RefCounted
## Combat sound recipes (design.md DS-SFX-01), layered through SfxMix: magic zaps and the
## fireball's roar and boom, the special's rising power-up sting, the grab grip and release, the
## toss and melee swing whooshes. Same soft palette as SfxRecipes (rounded sines, filtered noise
## for air and fire); scripts/bake_sfx.gd renders them into assets/sfx/<name>.wav.

const RECIPES := {
	# "Pew": a quick falling sine with a fast shimmer, a high sparkle over the top.
	"zap_bolt": {"volume": 0.5, "layers": [
		{"wave": "sine", "freq_start": 1900.0, "freq_end": 820.0, "freq_curve": 0.5, "attack": 0.002, "sustain": 0.03, "decay": 0.09, "vibrato_depth": 0.06, "vibrato_hz": 38.0, "seed": 40},
		{"wave": "triangle", "freq_start": 3800.0, "freq_end": 2600.0, "attack": 0.002, "sustain": 0.01, "decay": 0.06, "vibrato_depth": 0.1, "vibrato_hz": 55.0, "lowpass": 0.6, "gain": 0.3, "seed": 41},
	]},
	# A bigger, lower zap with a round body under it.
	"zap_heavy": {"volume": 0.62, "layers": [
		{"wave": "sine", "freq_start": 1200.0, "freq_end": 360.0, "freq_curve": 0.6, "attack": 0.003, "sustain": 0.06, "decay": 0.16, "vibrato_depth": 0.07, "vibrato_hz": 30.0, "seed": 42},
		{"wave": "sine", "freq_start": 320.0, "freq_end": 120.0, "freq_curve": 0.5, "attack": 0.004, "sustain": 0.05, "decay": 0.14, "gain": 0.6, "seed": 43},
		{"wave": "triangle", "freq_start": 2600.0, "freq_end": 1500.0, "attack": 0.002, "sustain": 0.02, "decay": 0.1, "vibrato_depth": 0.12, "vibrato_hz": 47.0, "lowpass": 0.5, "gain": 0.25, "seed": 44},
	]},
	# Whoosh-roar: a swelling band of air over a fluttering low growl.
	"fireball_launch": {"volume": 0.72, "layers": [
		{"wave": "noise", "attack": 0.06, "sustain": 0.12, "decay": 0.28, "lowpass": 0.22, "sustain_level": 0.8, "seed": 45},
		{"wave": "saw", "freq_start": 120.0, "freq_end": 70.0, "attack": 0.05, "sustain": 0.14, "decay": 0.24, "vibrato_depth": 0.12, "vibrato_hz": 13.0, "lowpass": 0.06, "gain": 0.7, "seed": 46},
	]},
	# Sparkle pop: a bright blip, a falling ting and a puff of air.
	"bolt_pop": {"volume": 0.5, "layers": [
		{"wave": "sine", "freq_start": 2200.0, "freq_end": 3300.0, "freq_curve": 0.4, "attack": 0.001, "sustain": 0.01, "decay": 0.05, "seed": 47},
		{"wave": "triangle", "freq_start": 1500.0, "freq_end": 650.0, "attack": 0.002, "sustain": 0.01, "decay": 0.08, "gain": 0.6, "seed": 48},
		{"wave": "noise", "attack": 0.001, "sustain": 0.005, "decay": 0.04, "lowpass": 0.5, "gain": 0.35, "seed": 49},
	]},
	# Fiery boom: a deep sine thump under a crackling roar (the bomb is plain noise).
	"fireball_boom": {"volume": 0.9, "layers": [
		{"wave": "sine", "freq_start": 140.0, "freq_end": 38.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.05, "decay": 0.3, "seed": 50},
		{"wave": "noise", "attack": 0.004, "sustain": 0.1, "decay": 0.42, "lowpass": 0.14, "sustain_level": 0.6, "gain": 0.9, "seed": 51},
		{"wave": "noise", "attack": 0.002, "sustain": 0.04, "decay": 0.18, "lowpass": 0.55, "gain": 0.25, "delay": 0.03, "seed": 52},
	]},
	# Power-up charge sting: two rising tones an octave apart with a shimmer of air.
	"special_charge": {"volume": 0.55, "layers": [
		{"wave": "triangle", "freq_start": 220.0, "freq_end": 880.0, "freq_curve": 0.8, "attack": 0.02, "sustain": 0.24, "decay": 0.12, "vibrato_depth": 0.03, "vibrato_hz": 9.0, "seed": 53},
		{"wave": "sine", "freq_start": 440.0, "freq_end": 1760.0, "freq_curve": 0.9, "attack": 0.03, "sustain": 0.22, "decay": 0.12, "vibrato_depth": 0.02, "vibrato_hz": 14.0, "gain": 0.45, "seed": 54},
		{"wave": "noise", "attack": 0.18, "sustain": 0.08, "decay": 0.12, "lowpass": 0.35, "sustain_level": 0.9, "gain": 0.2, "seed": 55},
	]},
	# Cloth grip: a soft fabric scrunch on a low thump.
	"grab": {"volume": 0.55, "layers": [
		{"wave": "noise", "attack": 0.002, "sustain": 0.02, "decay": 0.05, "lowpass": 0.3, "seed": 56},
		{"wave": "sine", "freq_start": 190.0, "freq_end": 90.0, "attack": 0.002, "sustain": 0.02, "decay": 0.07, "gain": 0.8, "seed": 57},
	]},
	# Letting go: a short soft breath of air.
	"grab_release": {"wave": "noise", "attack": 0.03, "sustain": 0.04, "decay": 0.12, "lowpass": 0.3, "sustain_level": 0.6, "volume": 0.35, "seed": 58},
	# The toss: a heavy body thud, then the air it is thrown through.
	"toss": {"volume": 0.85, "layers": [
		{"wave": "sine", "freq_start": 240.0, "freq_end": 48.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.05, "decay": 0.2, "seed": 59},
		{"wave": "noise", "attack": 0.002, "sustain": 0.03, "decay": 0.12, "lowpass": 0.12, "gain": 0.8, "seed": 60},
		{"wave": "noise", "attack": 0.08, "sustain": 0.06, "decay": 0.2, "lowpass": 0.4, "sustain_level": 0.7, "gain": 0.45, "delay": 0.04, "seed": 61},
	]},
	# Blade swish: bright air that swells and cuts off, with a faint metal sing.
	"swing_blade": {"volume": 0.42, "layers": [
		{"wave": "noise", "attack": 0.035, "sustain": 0.02, "decay": 0.07, "lowpass": 0.55, "sustain_level": 0.8, "seed": 62},
		{"wave": "sine", "freq_start": 1500.0, "freq_end": 900.0, "attack": 0.03, "sustain": 0.02, "decay": 0.06, "vibrato_depth": 0.02, "vibrato_hz": 20.0, "gain": 0.12, "seed": 63},
	]},
	# Unarmed: a short dull whoosh of air.
	"swing_air": {"wave": "noise", "attack": 0.03, "sustain": 0.015, "decay": 0.06, "lowpass": 0.22, "sustain_level": 0.8, "volume": 0.35, "seed": 64},
}
