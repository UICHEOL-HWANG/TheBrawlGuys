class_name StyleConfig
extends SpecialConfig
## Phase 5 fighting-style tunables (PRD §6.2), split out of GameConfig to keep files short.
## GameConfig extends this. A style reshapes the classic attack table (LightAttack, Combo,
## HeavyAttack, Grab groups): damage and knockback multipliers, reach and width multipliers,
## tick offsets, plus its own movement numbers. The ranged style replaces light and heavy with
## projectiles. knockback_taken multiplies the knockback a fighter of that style receives.

@export_group("StyleBoxer")
## Boxer (Barbarian, Rogue): fast combo, short reach.
@export_range(0.1, 3.0, 0.05) var boxer_damage_mul: float = 1.0
@export_range(0.1, 3.0, 0.05) var boxer_knockback_mul: float = 0.9
@export_range(0.3, 3.0, 0.05) var boxer_reach_mul: float = 0.85
@export_range(-10, 20, 1) var boxer_recovery_add: int = -2
@export_range(1.0, 20.0, 0.1) var boxer_move_speed: float = 6.6
@export_range(1.0, 25.0, 0.1) var boxer_jump_velocity: float = 9.5
@export_range(0.0, 80.0, 0.5) var boxer_air_acceleration: float = 24.0
@export_range(0.3, 2.0, 0.05) var boxer_knockback_taken: float = 1.0

@export_group("StyleWeapon")
## Weapon (Knight): slow, wide and long reach, big knockback, heavier body.
@export_range(0.1, 3.0, 0.05) var weapon_damage_mul: float = 1.2
@export_range(0.1, 3.0, 0.05) var weapon_knockback_mul: float = 1.15
@export_range(0.3, 3.0, 0.05) var weapon_reach_mul: float = 1.5
@export_range(0.3, 3.0, 0.05) var weapon_width_mul: float = 1.35
@export_range(-10, 20, 1) var weapon_startup_add: int = 3
@export_range(-10, 30, 1) var weapon_recovery_add: int = 5
@export_range(1.0, 20.0, 0.1) var weapon_move_speed: float = 5.7
@export_range(1.0, 25.0, 0.1) var weapon_jump_velocity: float = 8.6
@export_range(0.0, 80.0, 0.5) var weapon_air_acceleration: float = 16.0
@export_range(0.3, 2.0, 0.05) var weapon_knockback_taken: float = 0.8

@export_group("StyleRanged")
## Ranged (Mage): light fires bolts (hits 1-2 link like the light combo), heavy fires a charged
## heavy bolt; grab and throw are weak (ranged_melee_mul).
@export_range(0.1, 2.0, 0.05) var ranged_melee_mul: float = 0.6
@export_range(1.0, 20.0, 0.1) var ranged_move_speed: float = 5.6
@export_range(1.0, 25.0, 0.1) var ranged_jump_velocity: float = 9.0
@export_range(0.0, 80.0, 0.5) var ranged_air_acceleration: float = 20.0
@export_range(0.3, 2.0, 0.05) var ranged_knockback_taken: float = 1.2
@export_range(0.0, 30.0, 0.5) var bolt_damage: float = 3.0
@export_range(0.0, 30.0, 0.1) var bolt_base_knockback: float = 2.5
@export_range(0.0, 0.5, 0.005) var bolt_knockback_scaling: float = 0.04
@export_range(0.0, 2.0, 0.05) var bolt_launch_angle_y: float = 0.4
@export_range(0, 60, 1) var bolt_hitstun_ticks: int = 16
@export_range(0, 30, 1) var bolt_startup_ticks: int = 6
@export_range(1, 60, 1) var bolt_recovery_ticks: int = 10
@export_range(1.0, 40.0, 0.5) var bolt_speed: float = 14.0
@export_range(1.0, 30.0, 0.5) var bolt_range: float = 6.0
@export_range(0.05, 1.5, 0.05) var bolt_radius: float = 0.3
@export_range(0.1, 3.0, 0.05) var heavy_bolt_damage_mul: float = 0.9
@export_range(1.0, 40.0, 0.5) var heavy_bolt_speed: float = 11.0
@export_range(1.0, 30.0, 0.5) var heavy_bolt_range: float = 9.0
@export_range(0.05, 1.5, 0.05) var heavy_bolt_radius: float = 0.5

@export_group("BotStyle")
## Style-aware bots (PRD-BOT-02): ranged bots back off inside keep_distance and shoot inside
## fire_range; melee bots swing at bot_attack_range times their style's reach multiplier.
@export_range(0.5, 10.0, 0.1) var bot_ranged_keep_distance: float = 3.0
@export_range(1.0, 15.0, 0.1) var bot_ranged_fire_range: float = 6.5
## Bots fire a full gauge when the nearest foe is within the special's reach times this.
@export_range(0.2, 2.0, 0.05) var bot_special_reach_mul: float = 0.9
