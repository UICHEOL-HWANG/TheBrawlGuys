shader_type spatial;
render_mode unshaded, cull_front;
// Character-only thin outline (design.md DS-VIS-01 outline option, context F6): an inverted hull
// pushed out along normals. Width 0 (presets A/B) keeps it hidden behind the body.

global uniform float ds_outline_width;
global uniform vec4 ds_outline_color;

void vertex() {
	VERTEX += NORMAL * ds_outline_width;
}

void fragment() {
	ALBEDO = ds_outline_color.rgb;
}
