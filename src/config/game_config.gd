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

@export_group("Arena")
@export_range(4.0, 20.0, 0.1) var arena_radius: float = 10.0
@export_range(-30.0, -2.0, 0.5) var kill_y: float = -8.0

@export_group("Knockback")
@export_range(0.0, 3.0, 0.01) var global_knockback_mul: float = 1.0
@export_range(0.0, 0.2, 0.001) var hitstun_factor: float = 0.04
@export_range(0.0, 0.3, 0.005) var hitstop_light: float = 0.06
@export_range(0.0, 0.3, 0.005) var hitstop_heavy: float = 0.1
@export_range(0.0, 1.0, 0.01) var guard_damage_mul: float = 0.2
@export_range(0.0, 1.0, 0.01) var guard_knockback_mul: float = 0.0

@export_group("Loop")
@export_range(1, 10, 1) var max_ticks_per_frame: int = 5

@export_group("Camera")
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 60.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 3.0
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 14.0
@export_range(10.0, 80.0, 0.5) var cam_zoom_max: float = 40.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0

@export_group("Touch")
@export_range(0.05, 0.5, 0.01) var touch_hold_threshold: float = 0.15
