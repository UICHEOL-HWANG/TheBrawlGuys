class_name AttackData
extends RefCounted
## One attack's numbers as a sim value object (PRD §4.2-4.3). Phase 1 builds the light attack
## from GameConfig; Phase 5 styles reshape copies of these (StyleShape) per style.

## projectile_kind of a melee attack.
const MELEE := -1

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
## Projectile.Kind fired on the first active tick instead of a melee hitbox, or MELEE.
var projectile_kind: int = MELEE
var projectile_speed: float = 0.0
var projectile_ticks: int = 0
var projectile_radius: float = 0.0


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


static func make(p_damage: float, base: float, scaling: float, angle: float, startup: int, active: int,
		recovery: int, hitstop_seconds: float) -> AttackData:
	var a := AttackData.new()
	a.damage = p_damage
	a.base_knockback = base
	a.knockback_scaling = scaling
	a.launch_angle_y = angle
	a.startup_ticks = startup
	a.active_ticks = active
	a.recovery_ticks = recovery
	a.hitstop_ticks = SimTime.to_ticks(hitstop_seconds)
	return a


func copy() -> AttackData:
	var a := AttackData.new()
	a.damage = damage
	a.base_knockback = base_knockback
	a.knockback_scaling = knockback_scaling
	a.launch_angle_y = launch_angle_y
	a.startup_ticks = startup_ticks
	a.active_ticks = active_ticks
	a.recovery_ticks = recovery_ticks
	a.hitbox_forward = hitbox_forward
	a.hitbox_up = hitbox_up
	a.hitbox_half = hitbox_half
	a.hitstop_ticks = hitstop_ticks
	a.min_hitstun_ticks = min_hitstun_ticks
	a.projectile_kind = projectile_kind
	a.projectile_speed = projectile_speed
	a.projectile_ticks = projectile_ticks
	a.projectile_radius = projectile_radius
	return a


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks


## attack_ticks counts ticks since the attack began; the first attack tick is 1.
func is_active(attack_ticks: int) -> bool:
	return attack_ticks > startup_ticks and attack_ticks <= startup_ticks + active_ticks


## Melee hitbox live this tick (projectile attacks never hit with a hitbox).
func hits_melee(attack_ticks: int) -> bool:
	return projectile_kind == MELEE and is_active(attack_ticks)
