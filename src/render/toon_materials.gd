class_name ToonMaterials
extends RefCounted
## One shared ShaderMaterial per (color, rim) pair.
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
