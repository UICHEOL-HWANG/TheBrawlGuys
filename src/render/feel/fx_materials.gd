class_name FxMaterials
extends RefCounted
## Glowing effect parts (combat-motion B): unshaded, see-through, no shadows, so magic and fire
## read as light at match-camera distance. Every call builds its own material, since each effect
## fades its parts on its own (never share one between effects).


## An unshaded alpha material in `color`. on_top skips the depth test (pops drawn over bodies).
static func glow(color: Color, on_top: bool = false, priority: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = on_top
	mat.render_priority = priority
	mat.albedo_color = color
	return mat


## A glowing sphere of `radius` under parent.
static func sphere(parent: Node3D, radius: float, color: Color, on_top: bool = false, priority: int = 0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return attach(parent, s, color, on_top, priority)


## A flat glowing ring lying in the XZ plane (outer radius 1 before scaling, tube `thickness`).
static func ring(parent: Node3D, thickness: float, color: Color, on_top: bool = false, priority: int = 0) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 1.0 - thickness
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	return attach(parent, t, color, on_top, priority)


## A mesh with its own glow material under parent.
static func attach(parent: Node3D, mesh: Mesh, color: Color, on_top: bool = false, priority: int = 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow(color, on_top, priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Recolors mi; alpha >= 0 replaces the color's alpha.
static func tint(mi: MeshInstance3D, color: Color, alpha: float = -1.0) -> void:
	(mi.material_override as StandardMaterial3D).albedo_color = faded(color, alpha) if alpha >= 0.0 else color


static func set_alpha(mi: MeshInstance3D, alpha: float) -> void:
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color = faded(mat.albedo_color, alpha)


## `color` at `alpha` (tokens are opaque; effects layer them see-through).
static func faded(color: Color, alpha: float) -> Color:
	var c := color
	c.a = clampf(alpha, 0.0, 1.0)
	return c
