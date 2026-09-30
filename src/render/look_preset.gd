class_name LookPreset
extends RefCounted
## Character look presets for the gate (design.md DS-VIS-01/02, context F6), applied through
## global shader uniforms so every character material follows at once.
##   A  rim 0.35, no outline (design draft)
##   B  stronger rim, +15% saturation
##   C  softer rim, thin canopy_deep outline (characters only)

enum Look { A, B, C }

const PRESETS := {
	Look.A: {"rim": 0.35, "saturation": 1.0, "outline": 0.0},
	Look.B: {"rim": 0.5, "saturation": 1.15, "outline": 0.0},
	Look.C: {"rim": 0.25, "saturation": 1.0, "outline": 0.012},
}


## The look most recently passed to apply() (resolved: unknown values become A).
static var last_applied: int = Look.A


static func values_for(look: int) -> Dictionary:
	return PRESETS.get(look, PRESETS[Look.A])


## Shader-uniform values for a look, keyed by global uniform name (testable without a renderer).
static func uniforms_for(look: int) -> Dictionary:
	var p := values_for(look)
	return {
		"ds_rim_strength": float(p["rim"]),
		"ds_char_saturation": float(p["saturation"]),
		"ds_outline_width": float(p["outline"]),
		"ds_outline_color": DS.CANOPY_DEEP,
	}


static func apply(look: int) -> void:
	last_applied = look if PRESETS.has(look) else Look.A
	var u := uniforms_for(look)
	for key: String in u:
		RenderingServer.global_shader_parameter_set(key, u[key])
