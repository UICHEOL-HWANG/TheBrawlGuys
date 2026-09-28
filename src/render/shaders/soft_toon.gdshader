shader_type spatial;
// Soft toon (design.md DS-VIS-01): two soft bands, tinted shadows, optional rim, no outline.

global uniform vec4 ds_shadow_tint;
global uniform float ds_band_softness;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-ds_band_softness, ds_band_softness, ndl) * ATTENUATION;
	vec3 band = mix(ds_shadow_tint.rgb, vec3(1.0), lit);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength * lit;
	DIFFUSE_LIGHT += (band + vec3(rim)) * LIGHT_COLOR / PI;
}
