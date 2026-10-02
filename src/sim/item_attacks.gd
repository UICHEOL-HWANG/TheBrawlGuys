class_name ItemAttacks
extends RefCounted
## AttackSet entries for the second item set (PRD-ITEM-05/06), split out of AttackSet: the squeaky
## hammer (bat-like swing, launch almost straight up) and the feather glove (light jab).


static func hammer(c: GameConfig) -> AttackData:
	var a := _numbers(c.hammer_damage, c.hammer_base_knockback, c.hammer_knockback_scaling,
			c.hammer_launch_angle_y, c.hitstop_heavy)
	a.startup_ticks = c.hammer_startup_ticks
	a.active_ticks = c.hammer_active_ticks
	a.recovery_ticks = c.hammer_recovery_ticks
	a.hitbox_forward = c.hammer_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.hammer_hitbox_half_width, c.light_hitbox_half_height, c.hammer_hitbox_half_width)
	return a


static func glove(c: GameConfig) -> AttackData:
	var a := _numbers(c.glove_damage, c.glove_base_knockback, c.glove_knockback_scaling,
			c.glove_launch_angle_y, c.hitstop_light)
	a.startup_ticks = c.glove_startup_ticks
	a.active_ticks = c.glove_active_ticks
	a.recovery_ticks = c.glove_recovery_ticks
	a.hitbox_forward = c.glove_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.grab_half_width, c.light_hitbox_half_height, c.grab_half_width)
	return a


static func _numbers(damage: float, base: float, scaling: float, angle: float, hitstop_seconds: float) -> AttackData:
	var a := AttackData.new()
	a.damage = damage
	a.base_knockback = base
	a.knockback_scaling = scaling
	a.launch_angle_y = angle
	a.hitstop_ticks = SimTime.to_ticks(hitstop_seconds)
	return a
