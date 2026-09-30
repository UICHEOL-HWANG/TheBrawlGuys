shader_type spatial;
// Soft toon v2 (design.md DS-VIS-01, context F6): two soft bands, tinted shadows, optional rim,
// optional albedo texture, no outline. Characters read the global rim and saturation tokens so
// the look presets (LookPreset) retune every character at once.

global uniform vec4 ds_shadow_tint;
global uniform float ds_band_softness;
global uniform float ds_rim_strength;
global uniform float ds_char_saturation;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool is_character = false;

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	if (is_character) {
		float luma = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(luma), c, ds_char_saturation);
	}
	ALBEDO = clamp(c, 0.0, 1.0);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-ds_band_softness, ds_band_softness, ndl) * ATTENUATION;
	vec3 band = mix(ds_shadow_tint.rgb, vec3(1.0), lit);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Local lights (campfire, glowing mushrooms, Phase 4) fade out with distance; only the sun
		// lays the tinted shadow band over everything.
		band *= ATTENUATION;
	}
	float rim_amount = is_character ? ds_rim_strength : rim_strength;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount * lit;
	DIFFUSE_LIGHT += (band + vec3(rim)) * LIGHT_COLOR / PI;
}
