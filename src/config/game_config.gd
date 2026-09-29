class_name GameConfig
extends Resource
## Value ownership: GameConfig holds gameplay/feel tunables exposed on the debug panel.
## Art-direction constants (prop counts, light energies, mesh sizes) stay as named consts
## in render code; colors and UI sizes live only in DS tokens (src/ui/theme/tokens.gd).
## Every tunable number lives here. The debug panel builds a slider for each @export_range.
## Initial values: docs/PRD.md §4.5. Camera rules: docs/design.md GD-CAM-01.

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 25.0, 0.1) var jump_velocity: float = 9.0
@export_range(-80.0, -5.0, 0.5) var gravity: float = -25.0
@export_range(1, 4, 1) var max_jumps: int = 2
## Airborne steering toward the input direction (m/s^2); with no input only air_drag applies,
## so launched fighters keep their momentum after hitstun ends.
@export_range(0.0, 80.0, 0.5) var air_acceleration: float = 20.0
@export_range(0.0, 40.0, 0.5) var air_drag: float = 2.0

@export_group("Fighter")
@export_range(0.2, 1.0, 0.01) var fighter_radius: float = 0.45
@export_range(0.8, 3.0, 0.05) var fighter_height: float = 1.6
@export_range(0.0, 1.0, 0.01) var hitstun_ground_friction: float = 0.85

@export_group("Arena")
@export_range(4.0, 20.0, 0.1) var arena_radius: float = 10.0
@export_range(-30.0, -2.0, 0.5) var kill_y: float = -8.0

@export_group("Rules")
@export_range(1, 9, 1) var stocks: int = 3
@export_range(1.0, 20.0, 0.5) var respawn_height: float = 6.0
@export_range(0.0, 5.0, 0.1) var respawn_invuln: float = 2.0
@export_range(2.0, 40.0, 0.5) var blast_margin: float = 12.0

@export_group("Knockback")
@export_range(0.0, 10.0, 0.01) var global_knockback_mul: float = 1.0
@export_range(0.0, 0.2, 0.001) var hitstun_factor: float = 0.04
@export_range(0.0, 0.3, 0.005) var hitstop_light: float = 0.06
@export_range(0.0, 0.3, 0.005) var hitstop_heavy: float = 0.1
@export_range(0.0, 1.0, 0.01) var guard_damage_mul: float = 0.2
@export_range(0.0, 1.0, 0.01) var guard_knockback_mul: float = 0.0

@export_group("LightAttack")
@export_range(0.0, 30.0, 0.5) var light_damage: float = 4.0
@export_range(0.0, 30.0, 0.1) var light_base_knockback: float = 3.0
@export_range(0.0, 0.5, 0.005) var light_knockback_scaling: float = 0.05
@export_range(0.0, 2.0, 0.05) var light_launch_angle_y: float = 0.6
@export_range(0, 30, 1) var light_startup_ticks: int = 3
@export_range(1, 30, 1) var light_active_ticks: int = 3
@export_range(0, 60, 1) var light_recovery_ticks: int = 8
@export_range(0.0, 3.0, 0.05) var light_hitbox_forward: float = 0.8
@export_range(0.0, 3.0, 0.05) var light_hitbox_up: float = 0.9
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_width: float = 0.45
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_height: float = 0.45

@export_group("Bot")
@export_range(0.5, 5.0, 0.1) var bot_attack_range: float = 1.4
@export_range(0, 120, 1) var bot_attack_cooldown_ticks: int = 30
@export_range(0.3, 1.0, 0.01) var bot_edge_ratio: float = 0.8

@export_group("Feel")
@export_range(0.0, 0.2, 0.001) var shake_per_knockback: float = 0.02
@export_range(0.0, 3.0, 0.05) var shake_max: float = 0.6
@export_range(0.5, 30.0, 0.5) var shake_decay: float = 8.0
@export_range(1.0, 30.0, 0.5) var blink_hz: float = 10.0
@export_range(1.0, 40.0, 0.5) var blink_hz_end: float = 20.0
@export_range(0.0, 40.0, 0.5) var spark_large_threshold: float = 8.0

@export_group("Loop")
@export_range(1, 10, 1) var max_ticks_per_frame: int = 5

@export_group("Camera")
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 60.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 3.0
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 14.0
@export_range(10.0, 150.0, 0.5) var cam_zoom_max: float = 70.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0

@export_group("Touch")
@export_range(0.05, 0.5, 0.01) var touch_hold_threshold: float = 0.15


## Hash of every script variable (D1). Snapshots and replays store it so a run can only be
## restored or verified against the exact same tuning.
func fingerprint() -> int:
	var values: Array = []
	for p: Dictionary in get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append([p["name"], get(p["name"])])
	return hash(values)
