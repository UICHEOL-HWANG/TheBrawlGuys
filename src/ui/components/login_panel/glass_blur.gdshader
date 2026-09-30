// Frosted glass (design.md DS-CMP-14): the scene behind the card, blurred through the screen
// texture mipmaps plus a 3x3 tap, then tinted by the stylebox color (COLOR) at tint_strength.
// Where screen mipmaps are missing (Compatibility) the script raises tint_strength instead.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 3.5;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * exp2(blur_lod);
	vec3 sum = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * step_uv, blur_lod).rgb;
		}
	}
	COLOR = vec4(mix(sum / 9.0, COLOR.rgb, tint_strength), COLOR.a);
}
