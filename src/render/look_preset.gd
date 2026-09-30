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


static func values_for(look: int) -> Dictionary:
	return PRESETS.get(look, PRESETS[Look.A])


static func apply(look: int) -> void:
	var p := values_for(look)
	RenderingServer.global_shader_parameter_set("ds_rim_strength", float(p["rim"]))
	RenderingServer.global_shader_parameter_set("ds_char_saturation", float(p["saturation"]))
	RenderingServer.global_shader_parameter_set("ds_outline_width", float(p["outline"]))
	RenderingServer.global_shader_parameter_set("ds_outline_color", DS.CANOPY_DEEP)
