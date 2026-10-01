class_name KnockdownConfig
extends Resource
## Combat-depth C tunables (PRD §4.3): directional influence, knockdown and getup options, tech.
## DefenseConfig extends this, so every value here is a GameConfig value (debug panel sliders;
## the DI / Knockdown / Tech groups enter GameConfig.fingerprint()). Frames are sim ticks (60 Hz).

@export_group("DI")
## The stick held when a launch's hitstop ends turns the horizontal launch direction toward the
## stick's side by up to this many degrees (full when the stick is perpendicular to the launch).
@export_range(0.0, 45.0, 0.5) var di_max_deg: float = 15.0

@export_group("Knockdown")
## A clean hit at least this strong that sends the target up makes it tumble: landing while still
## tumbling (no jump, attack or dodge since) knocks it down.
@export_range(0.0, 40.0, 0.5) var knockdown_min_knockback: float = 8.0
## Lying fighters stand up by themselves after knockdown_ticks; their getup options open after
## knockdown_min_ticks. Hits on a lying fighter push knockdown_hit_knockback_mul as hard and never
## knock it down again (no lock).
@export_range(1, 240, 1) var knockdown_ticks: int = 60
@export_range(0, 120, 1) var knockdown_min_ticks: int = 10
@export_range(0.0, 1.0, 0.05) var knockdown_hit_knockback_mul: float = 0.5
## Standing up (jump / guard, or lying the full time) takes getup_stand_ticks; standing up and
## rolling up are intangible for their first getup_intangible_ticks.
@export_range(1, 60, 1) var getup_stand_ticks: int = 18
@export_range(0, 60, 1) var getup_intangible_ticks: int = 14
## Getup roll (a direction held): moves getup_roll_distance over getup_roll_move_ticks, then
## stands still for getup_roll_recovery_ticks. Tech rolls move the same way.
@export_range(0.5, 6.0, 0.1) var getup_roll_distance: float = 2.6
@export_range(1, 60, 1) var getup_roll_move_ticks: int = 16
@export_range(0, 60, 1) var getup_roll_recovery_ticks: int = 8
## Getup attack (light): intangible through its startup, then hits every foe within
## getup_attack_radius of the fighter once.
@export_range(0, 40, 1) var getup_attack_startup_ticks: int = 8
@export_range(1, 30, 1) var getup_attack_active_ticks: int = 4
@export_range(0, 60, 1) var getup_attack_recovery_ticks: int = 16
@export_range(0.3, 3.0, 0.05) var getup_attack_radius: float = 1.3
@export_range(0.0, 30.0, 0.5) var getup_attack_damage: float = 5.0
@export_range(0.0, 30.0, 0.1) var getup_attack_base_knockback: float = 5.0
@export_range(0.0, 0.5, 0.005) var getup_attack_knockback_scaling: float = 0.04
@export_range(0.0, 2.0, 0.05) var getup_attack_launch_angle_y: float = 0.4

@export_group("Tech")
## Guard pressed while tumbling arms a tech for tech_window_ticks; each press then locks further
## presses until tech_window_ticks + tech_lockout_ticks have passed (no mashing).
@export_range(1, 60, 1) var tech_window_ticks: int = 12
@export_range(0, 120, 1) var tech_lockout_ticks: int = 40
## A tech in place lasts tech_ticks; techs (in place or rolling) are intangible for their first
## tech_intangible_ticks.
@export_range(1, 60, 1) var tech_ticks: int = 14
@export_range(0, 60, 1) var tech_intangible_ticks: int = 12

@export_group("BotGetup")
## Share of a bot's launches it tries to tech, pressing guard once it falls within bot_tech_height
## of the floor (BotGetup).
@export_range(0.0, 1.0, 0.05) var bot_tech_chance: float = 0.35
@export_range(0.1, 3.0, 0.05) var bot_tech_height: float = 0.9
