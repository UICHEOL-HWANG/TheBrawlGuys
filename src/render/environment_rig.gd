class_name EnvironmentRig
extends Node3D
## Warm midday sun, sky ambience and soft bloom (design.md §0 reference A, DS-VIS-01).

const SUN_ROTATION_DEG := Vector3(-55.0, 35.0, 0.0)
## Retuned (Task 10 review fix round 1): soft_toon.gdshader's light() writes
## DIFFUSE_LIGHT without dividing by albedo headroom, so SUN_ENERGY + AMBIENT_ENERGY
## must sum low enough that a sunlit DS albedo lands near its own token value
## instead of overexposing. Measured against DS.GRASS #A5D65A -- see task-10-report.md.
const SUN_ENERGY := 0.75
const AMBIENT_ENERGY := 0.42
const GLOW_INTENSITY := 0.35

## gl_compatibility (Web export) renders noticeably brighter/more saturated than
## Forward+/Mobile at the same energies (Task 12 review fix round 1 -- measured
## with headless-Chrome web captures: sunlit arena-top and outer-grass pixels
## both ran ~1.35-1.4x too bright/channel vs desktop, a near-uniform ratio, not
## just a missing-bloom difference). Tuned down empirically until a sunlit
## arena-top pixel landed within ~+/-12 of DS.GRASS #A5D65A (165,214,90) in an
## actual web export capture. See task-12-report.md fix round 1 for iterations.
const SUN_ENERGY_COMPAT := 0.30
const AMBIENT_ENERGY_COMPAT := 0.27
const GLOW_INTENSITY_COMPAT := 0.20

var _env: Environment
var _sun: DirectionalLight3D


func setup() -> void:
	var is_compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var sun_energy := SUN_ENERGY_COMPAT if is_compat else SUN_ENERGY
	var ambient_energy := AMBIENT_ENERGY_COMPAT if is_compat else AMBIENT_ENERGY
	var glow_intensity := GLOW_INTENSITY_COMPAT if is_compat else GLOW_INTENSITY

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = DS.SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = DS.SKY
	_env.ambient_light_energy = ambient_energy
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.glow_enabled = true
	_env.glow_intensity = glow_intensity
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = SUN_ROTATION_DEG
	_sun.light_color = DS.GLOW
	_sun.light_energy = sun_energy
	_sun.shadow_enabled = true
	add_child(_sun)


func apply_quality(level: int) -> void:
	var s := Quality.settings(level)
	_sun.shadow_enabled = bool(s["shadows"])
	_env.glow_enabled = bool(s["glow"])
	Engine.max_fps = int(s["max_fps"])


func environment() -> Environment:
	return _env


func sun() -> DirectionalLight3D:
	return _sun
