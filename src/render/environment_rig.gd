class_name EnvironmentRig
extends Node3D
## Warm midday sun, sky ambience and soft bloom (design.md §0 reference A, DS-VIS-01).

const SUN_ROTATION_DEG := Vector3(-55.0, 35.0, 0.0)
const SUN_ENERGY := 1.2
const AMBIENT_ENERGY := 0.55
const GLOW_INTENSITY := 0.35


func setup() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DS.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DS.SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.light_color = DS.GLOW
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	add_child(sun)
