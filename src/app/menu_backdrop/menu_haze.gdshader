// Menu haze (design.md DS-LAY-03): desaturates the diorama and lays a warm sage-gray haze over
// it, so the live scene reads as a calm background. amount 1 = fully hazed (entrance start).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 haze_color : source_color;
uniform float amount : hint_range(0.0, 1.0) = 0.34;
uniform float desaturate : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(luma), desaturate);
	COLOR = vec4(mix(scene, haze_color.rgb, amount), 1.0);
}
