class_name ItemExtrasConfig
extends Resource
## The second item set (PRD-ITEM-05..07): squeaky hammer, feather glove, banana peel. The base of
## the GameConfig chain (DdaConfig extends this), so every value is a GameConfig value with a
## debug panel slider. "ItemExtras" is a sim group: it enters the fingerprint.

@export_group("ItemExtras")
## Box drops draw from all six kinds instead of the classic three. Off by default so classic
## configs (replay tests, Phase 4 compat) draw exactly the old kinds; default_config.tres turns
## it on for the game. The draw itself is the same single call either way.
@export var item_pool_extended: bool = false
## Squeaky hammer: a bat-like swing whose launch points almost straight up.
@export_range(1, 20, 1) var hammer_uses: int = 4
@export_range(0.0, 40.0, 0.5) var hammer_damage: float = 7.0
@export_range(0.0, 30.0, 0.1) var hammer_base_knockback: float = 8.5
@export_range(0.0, 0.5, 0.005) var hammer_knockback_scaling: float = 0.1
@export_range(0.0, 12.0, 0.1) var hammer_launch_angle_y: float = 6.0
@export_range(0, 40, 1) var hammer_startup_ticks: int = 4
@export_range(1, 30, 1) var hammer_active_ticks: int = 4
@export_range(0, 60, 1) var hammer_recovery_ticks: int = 20
@export_range(0.0, 3.0, 0.05) var hammer_hitbox_forward: float = 1.1
@export_range(0.1, 2.0, 0.05) var hammer_hitbox_half_width: float = 0.55
## Feather glove: a light jab; a clean hit makes the target light for glove_light_time, and light
## fighters take glove_light_knockback_mul of every knockback.
@export_range(1, 20, 1) var glove_uses: int = 3
@export_range(0.0, 40.0, 0.5) var glove_damage: float = 4.0
@export_range(0.0, 30.0, 0.1) var glove_base_knockback: float = 4.0
@export_range(0.0, 0.5, 0.005) var glove_knockback_scaling: float = 0.04
@export_range(0.0, 2.0, 0.05) var glove_launch_angle_y: float = 0.4
@export_range(0, 40, 1) var glove_startup_ticks: int = 3
@export_range(1, 30, 1) var glove_active_ticks: int = 3
@export_range(0, 60, 1) var glove_recovery_ticks: int = 12
@export_range(0.0, 3.0, 0.05) var glove_hitbox_forward: float = 1.0
@export_range(0.5, 15.0, 0.5) var glove_light_time: float = 5.0
@export_range(1.0, 3.0, 0.05) var glove_light_knockback_mul: float = 1.5
## Banana peel: thrown like a rock but flies through fighters and lies where it lands. Its thrower
## may step on it for banana_grace_time; after that a grounded fighter within
## fighter_radius + banana_trigger_radius slips into a knockdown, sliding at banana_slip_speed.
@export_range(0.0, 3.0, 0.05) var banana_grace_time: float = 0.75
@export_range(0.1, 1.5, 0.05) var banana_trigger_radius: float = 0.35
@export_range(0.0, 10.0, 0.5) var banana_slip_speed: float = 4.0
@export_range(0.0, 20.0, 0.5) var banana_damage: float = 3.0
