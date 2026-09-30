class_name SpecialConfig
extends DefenseConfig
## Phase 5 special-move tunables (PRD §6.2.1), split out of GameConfig to keep files short.
## GameConfig extends StyleConfig extends this, so every value here is a GameConfig value: the
## debug panel shows each @export_range and the sim groups enter GameConfig.fingerprint().
## Frames are sim ticks (60 Hz), distances metres, speeds m/s.

@export_group("Special")
## Gauge (0..SpecialGauge.MAX) gained per % of damage dealt / taken; full = one special.
@export_range(0.0, 5.0, 0.05) var special_gauge_per_damage_dealt: float = 0.6
@export_range(0.0, 5.0, 0.05) var special_gauge_per_damage_taken: float = 0.45
## Invulnerable ticks from the start of a special (covers the startups below). Special and bolt
## recoveries stay >= 1 so the last active / firing tick is always stepped before the state ends.
@export_range(0, 60, 1) var special_invuln_ticks: int = 12

@export_group("SpecialSlam")
## Barbarian "ground slam": radial blast around the user on its active ticks.
@export_range(0.0, 40.0, 0.5) var slam_damage: float = 15.0
@export_range(0.0, 30.0, 0.1) var slam_base_knockback: float = 6.0
@export_range(0.0, 0.5, 0.005) var slam_knockback_scaling: float = 0.1
@export_range(0.0, 3.0, 0.05) var slam_launch_angle_y: float = 1.0
@export_range(0, 60, 1) var slam_startup_ticks: int = 11
@export_range(1, 30, 1) var slam_active_ticks: int = 5
@export_range(1, 90, 1) var slam_recovery_ticks: int = 24
@export_range(0.5, 8.0, 0.1) var slam_radius: float = 3.2

@export_group("SpecialRush")
## Rogue "dash rush": dashes forward hitting every rush_hit_interval ticks, the last hit launches.
@export_range(0.0, 20.0, 0.5) var rush_damage: float = 3.0
@export_range(0.0, 20.0, 0.1) var rush_base_knockback: float = 4.5
@export_range(0, 60, 1) var rush_hitstun_ticks: int = 14
@export_range(1, 30, 1) var rush_hit_interval: int = 6
@export_range(0.0, 30.0, 0.5) var rush_speed: float = 9.0
@export_range(0.0, 40.0, 0.5) var rush_finish_damage: float = 8.0
@export_range(0.0, 30.0, 0.1) var rush_finish_base_knockback: float = 7.5
@export_range(0.0, 0.5, 0.005) var rush_finish_knockback_scaling: float = 0.11
@export_range(0.0, 3.0, 0.05) var rush_finish_launch_angle_y: float = 1.1
@export_range(0, 60, 1) var rush_startup_ticks: int = 11
@export_range(1, 90, 1) var rush_active_ticks: int = 30
@export_range(1, 90, 1) var rush_recovery_ticks: int = 20
@export_range(0.0, 3.0, 0.05) var rush_hitbox_forward: float = 0.9
@export_range(0.1, 2.0, 0.05) var rush_hitbox_half_width: float = 0.7

@export_group("SpecialSpin")
## Knight "spin slash": hits all around on its active ticks with a strong, low launch.
@export_range(0.0, 40.0, 0.5) var spin_damage: float = 13.0
@export_range(0.0, 30.0, 0.1) var spin_base_knockback: float = 8.5
@export_range(0.0, 0.5, 0.005) var spin_knockback_scaling: float = 0.11
@export_range(0.0, 3.0, 0.05) var spin_launch_angle_y: float = 0.3
@export_range(0, 60, 1) var spin_startup_ticks: int = 10
@export_range(1, 30, 1) var spin_active_ticks: int = 10
@export_range(1, 90, 1) var spin_recovery_ticks: int = 22
@export_range(0.5, 8.0, 0.1) var spin_radius: float = 2.6

@export_group("SpecialFireball")
## Mage "big fireball": a slow projectile that explodes on contact or at the end of its range.
@export_range(0.0, 40.0, 0.5) var fireball_damage: float = 16.0
@export_range(0.0, 30.0, 0.1) var fireball_base_knockback: float = 8.0
@export_range(0.0, 0.5, 0.005) var fireball_knockback_scaling: float = 0.11
@export_range(0.0, 3.0, 0.05) var fireball_launch_angle_y: float = 0.7
@export_range(0, 60, 1) var fireball_startup_ticks: int = 16
@export_range(1, 90, 1) var fireball_recovery_ticks: int = 26
@export_range(1.0, 30.0, 0.5) var fireball_speed: float = 8.0
@export_range(1.0, 30.0, 0.5) var fireball_range: float = 11.0
@export_range(0.1, 2.0, 0.05) var fireball_radius: float = 0.8
@export_range(0.5, 6.0, 0.1) var fireball_explode_radius: float = 2.4
