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
## Compat with glow OFF (Quality LOW, the web default -- Phase 3 fix wave F2). The pair above
## was tuned with bloom adding light; without it the web toon look landed dark and olive
## (arena-top pixel (114,155,58) vs DS.GRASS (165,214,90)). Retuned against a LOW web capture: sun/ambient
## 0.42/0.38 -> (134,180,69), 0.58/0.52 -> (155,208,81), 0.62/0.56 -> (160,215,84), i.e.
## within +/-12 of DS.GRASS. See fix-wave-report.md F2.
const SUN_ENERGY_COMPAT_NO_GLOW := 0.62
const AMBIENT_ENERGY_COMPAT_NO_GLOW := 0.56

var _env: Environment
var _sun: DirectionalLight3D


func setup() -> void:
	var is_compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var e := energies(is_compat, true)
	var sun_energy := float(e["sun"])
	var ambient_energy := float(e["ambient"])
	var glow_intensity := float(e["glow"])

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


## Light energies for a renderer and bloom state ({sun, ambient, glow}). Pure so it can be tested
## headless; only Compatibility with glow off needs its own measured pair.
static func energies(is_compat: bool, glow_on: bool) -> Dictionary:
	if not is_compat:
		return {"sun": SUN_ENERGY, "ambient": AMBIENT_ENERGY, "glow": GLOW_INTENSITY}
	if glow_on:
		return {"sun": SUN_ENERGY_COMPAT, "ambient": AMBIENT_ENERGY_COMPAT, "glow": GLOW_INTENSITY_COMPAT}
	return {"sun": SUN_ENERGY_COMPAT_NO_GLOW, "ambient": AMBIENT_ENERGY_COMPAT_NO_GLOW, "glow": GLOW_INTENSITY_COMPAT}


func apply_quality(level: int) -> void:
	var s := Quality.settings(level)
	var glow_on := bool(s["glow"])
	var is_compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var e := energies(is_compat, glow_on)
	_sun.shadow_enabled = bool(s["shadows"])
	_sun.light_energy = float(e["sun"])
	_env.ambient_light_energy = float(e["ambient"])
	_env.glow_intensity = float(e["glow"])
	_env.glow_enabled = glow_on
	Engine.max_fps = int(s["max_fps"])


func environment() -> Environment:
	return _env


func sun() -> DirectionalLight3D:
	return _sun
