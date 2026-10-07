class_name SfxRecipes
extends RefCounted
## Sound recipes (design.md DS-SFX-01): soft, bouncy, wooden/grassy/watery tones — rounded sine
## and triangle bodies, short noise for air and water, no harsh square leads. Every sound is
## original (context F9); scripts/bake_sfx.gd renders them into assets/sfx/<name>.wav.

const RECIPES := {
	"hit_light": {"wave": "triangle", "freq_start": 520.0, "freq_end": 180.0, "freq_curve": 0.5, "attack": 0.002, "sustain": 0.03, "decay": 0.09, "noise_mix": 0.25, "lowpass": 0.5, "volume": 0.7, "seed": 11},
	"hit_heavy": {"wave": "sine", "freq_start": 300.0, "freq_end": 60.0, "freq_curve": 0.4, "attack": 0.002, "sustain": 0.06, "decay": 0.22, "noise_mix": 0.3, "lowpass": 0.35, "volume": 0.9, "seed": 12},
	"guard": {"wave": "sine", "freq_start": 900.0, "freq_end": 700.0, "attack": 0.002, "sustain": 0.02, "decay": 0.15, "vibrato_depth": 0.05, "vibrato_hz": 30.0, "volume": 0.55, "seed": 13},
	"jump": {"wave": "sine", "freq_start": 260.0, "freq_end": 620.0, "freq_curve": 0.7, "attack": 0.005, "sustain": 0.05, "decay": 0.06, "volume": 0.5, "seed": 14},
	"land": {"wave": "noise", "attack": 0.002, "sustain": 0.02, "decay": 0.1, "lowpass": 0.12, "volume": 0.5, "seed": 15},
	"ringout_splash": {"wave": "noise", "attack": 0.01, "sustain": 0.15, "decay": 0.5, "lowpass": 0.3, "sustain_level": 0.5, "volume": 0.85, "seed": 16},
	"ringout_whistle": {"wave": "sine", "freq_start": 1400.0, "freq_end": 380.0, "freq_curve": 1.3, "attack": 0.01, "sustain": 0.5, "decay": 0.2, "vibrato_depth": 0.02, "vibrato_hz": 9.0, "volume": 0.6, "seed": 17},
	"respawn": {"wave": "triangle", "freq_start": 440.0, "freq_end": 990.0, "freq_curve": 0.6, "attack": 0.02, "sustain": 0.2, "decay": 0.25, "vibrato_depth": 0.03, "vibrato_hz": 7.0, "volume": 0.5, "seed": 18},
	"item_pickup": {"wave": "sine", "freq_start": 660.0, "freq_end": 1320.0, "freq_curve": 0.3, "attack": 0.003, "sustain": 0.04, "decay": 0.08, "volume": 0.55, "seed": 19},
	"item_throw": {"wave": "noise", "attack": 0.01, "sustain": 0.08, "decay": 0.1, "lowpass": 0.45, "volume": 0.45, "seed": 20},
	"squeak": {"wave": "sine", "freq_start": 1500.0, "freq_end": 900.0, "freq_curve": 0.6, "attack": 0.003, "sustain": 0.06, "decay": 0.12, "vibrato_depth": 0.08, "vibrato_hz": 24.0, "volume": 0.6, "seed": 25},
	"slip": {"wave": "triangle", "freq_start": 820.0, "freq_end": 160.0, "freq_curve": 1.2, "attack": 0.004, "sustain": 0.14, "decay": 0.18, "vibrato_depth": 0.04, "vibrato_hz": 11.0, "volume": 0.55, "seed": 26},
	"explosion": {"wave": "noise", "attack": 0.003, "sustain": 0.12, "decay": 0.6, "lowpass": 0.18, "sustain_level": 0.6, "volume": 0.95, "seed": 21},
	"ui_click": {"wave": "sine", "freq_start": 1200.0, "freq_end": 900.0, "attack": 0.001, "sustain": 0.01, "decay": 0.04, "volume": 0.45, "seed": 22},
	"ui_confirm": {"wave": "triangle", "freq_start": 660.0, "freq_end": 990.0, "freq_curve": 0.5, "attack": 0.003, "sustain": 0.05, "decay": 0.12, "volume": 0.5, "seed": 23},
	"ui_cancel": {"wave": "triangle", "freq_start": 700.0, "freq_end": 420.0, "attack": 0.003, "sustain": 0.05, "decay": 0.1, "volume": 0.45, "seed": 24},
}


## Every recipe bake_sfx.gd renders: these plus the layered combat sounds (CombatSfxRecipes).
static func all() -> Dictionary:
	return RECIPES.merged(CombatSfxRecipes.RECIPES)


## Where scripts/bake_sfx.gd writes the recipe's placeholder.
static func path(name: String) -> String:
	return "res://assets/sfx/%s.wav" % name


## What to load: always the .wav (baked placeholder or designed hit from scripts/music/hits.py).
## The web build plays both formats as Web Audio samples, but an .ogg is first decoded to PCM on
## the main thread at its first play; a .wav costs nothing to turn into a sample.
static func stream_path(name: String) -> String:
	return path(name)
