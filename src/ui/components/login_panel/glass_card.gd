class_name GlassCard
extends PanelContainer
## Frosted glass card (design.md DS-CMP-14): extra-large radius, sage tint over the blurred
## scene, thin light edge and a soft shadow. The blur reads the screen texture; the Compatibility
## renderer (web) has no screen mipmaps, so there the tint is stronger instead of blurring.

const SHADER := preload("res://src/ui/components/login_panel/glass_blur.gdshader")
const EDGE_WIDTH := 2


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.GLASS_TINT
	sb.set_corner_radius_all(DS.RADIUS_XL)
	sb.border_color = DS.GLASS_EDGE
	sb.set_border_width_all(EDGE_WIDTH)
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = DS.SHADOW_SOFT_OFFSET
	sb.shadow_size = DS.SHADOW_SOFT_SIZE * 2
	sb.content_margin_left = DS.S7
	sb.content_margin_right = DS.S7
	sb.content_margin_top = DS.S7
	sb.content_margin_bottom = DS.S6
	add_theme_stylebox_override("panel", sb)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("blur_lod", DS.GLASS_BLUR_LOD)
	mat.set_shader_parameter("tint_strength", tint_strength(RenderingServer.get_current_rendering_method()))
	material = mat


static func tint_strength(rendering_method: String) -> float:
	return DS.GLASS_TINT_STRENGTH_NO_BLUR if rendering_method == "gl_compatibility" else DS.GLASS_TINT_STRENGTH
