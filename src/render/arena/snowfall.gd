class_name Snowfall
extends CPUParticles3D
## Light snowfall over the frozen pond (DS-THM-02 winter ambience): small flakes drift down over
## the whole arena, already falling when the match starts. The flake count follows the render
## quality (Quality.particle_scale) and reduce motion ([accessibility] reduce_motion) turns the
## snow off, like the other ambient effects. Drawing only.

const FLAKES := 240
const FLAKE_RADIUS := 0.09
const AREA := Vector3(36.0, 1.0, 30.0)
## Flakes start below the match camera (which sits about 10 m up or higher) and melt near the ice.
const TOP := 9.0
const LIFETIME := 8.0
const FALL_SPEED := Vector2(0.8, 1.4)
const SWAY := 0.35


## reduce_motion: no snow at all; otherwise FLAKES scaled by the quality level.
func setup(config: GameConfig, reduce_motion: bool) -> void:
	var count := 0 if reduce_motion else roundi(FLAKES * Quality.particle_scale(config))
	emitting = count > 0
	visible = count > 0
	amount = maxi(count, 1)
	if count == 0:
		return
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # flake shadows read as specks of dirt
	# CPUParticles3D culls by a zero-size box at its origin (above the camera view): cover the fall.
	custom_aabb = AABB(Vector3(-AREA.x * 0.5, -TOP, -AREA.z * 0.5), Vector3(AREA.x, TOP + AREA.y, AREA.z))
	lifetime = LIFETIME
	preprocess = LIFETIME
	position = Vector3(0, TOP, 0)
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = AREA * 0.5
	direction = Vector3.DOWN
	spread = 15.0
	gravity = Vector3(SWAY, 0.0, 0.0)
	initial_velocity_min = FALL_SPEED.x
	initial_velocity_max = FALL_SPEED.y
	var flake := SphereMesh.new()
	flake.radius = FLAKE_RADIUS
	flake.height = FLAKE_RADIUS * 2.0
	flake.radial_segments = 6
	flake.rings = 3
	flake.material = ToonMaterials.toon(DS.WHITE)
	mesh = flake
	restart()  # applies preprocess: the air is already full of snow on the first frame


func flake_count() -> int:
	return amount if emitting else 0
