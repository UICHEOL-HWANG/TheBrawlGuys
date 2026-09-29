class_name ToonMaterials
extends RefCounted
## One shared ShaderMaterial per (color, rim) pair, plus unshaded translucent materials for shadows and bubbles.
## Cached materials are SHARED between all callers: never mutate them. Callers needing
## per-instance changes (hit flash, per-fighter rim) must duplicate() first.

const SHADER := preload("res://src/render/shaders/soft_toon.gdshader")

static var _cache: Dictionary = {}


static func toon(color: Color, rim: float = 0.0) -> ShaderMaterial:
	var key := "%s|%.3f" % [color.to_html(), rim]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("rim_strength", rim)
	_cache[key] = mat
	return mat


static var _translucent_cache: Dictionary = {}


## Unshaded alpha-blended material (ground shadows, guard bubbles). Shared: never mutate.
static func translucent(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _translucent_cache.has(key):
		return _translucent_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	_translucent_cache[key] = mat
	return mat
