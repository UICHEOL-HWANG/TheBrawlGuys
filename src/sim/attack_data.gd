class_name AttackData
extends RefCounted
## One attack's numbers as a sim value object (PRD §4.2-4.3). Phase 1 builds the light attack
## from GameConfig; Phase 5 styles will build attacks from style data instead.

var damage: float = 0.0
var base_knockback: float = 0.0
var knockback_scaling: float = 0.0
var launch_angle_y: float = 0.0
var startup_ticks: int = 0
var active_ticks: int = 1
var recovery_ticks: int = 0
var hitbox_forward: float = 0.0
var hitbox_up: float = 0.0
var hitbox_half: Vector3 = Vector3.ONE
var hitstop_ticks: int = 0
## Hitstun floor in ticks; link hits use it so the next combo hit connects (context E1).
var min_hitstun_ticks: int = 0


static func light_from(config: GameConfig) -> AttackData:
	var a := AttackData.new()
	a.damage = config.light_damage
	a.base_knockback = config.light_base_knockback
	a.knockback_scaling = config.light_knockback_scaling
	a.launch_angle_y = config.light_launch_angle_y
	a.startup_ticks = config.light_startup_ticks
	a.active_ticks = config.light_active_ticks
	a.recovery_ticks = config.light_recovery_ticks
	a.hitbox_forward = config.light_hitbox_forward
	a.hitbox_up = config.light_hitbox_up
	a.hitbox_half = Vector3(config.light_hitbox_half_width, config.light_hitbox_half_height, config.light_hitbox_half_width)
	a.hitstop_ticks = SimTime.to_ticks(config.hitstop_light)
	return a


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks


## attack_ticks counts ticks since the attack began; the first attack tick is 1.
func is_active(attack_ticks: int) -> bool:
	return attack_ticks > startup_ticks and attack_ticks <= startup_ticks + active_ticks
