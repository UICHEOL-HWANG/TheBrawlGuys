class_name SpinSlash
extends Special
## Knight "회전 베기" (spin slash): a full-circle sweep; during its active ticks every foe level
## with him inside spin_radius is hit once and launched hard and low, straight away from him.

const ID := "spin_slash"


func attack(c: GameConfig) -> AttackData:
	return AttackData.make(c.spin_damage, c.spin_base_knockback, c.spin_knockback_scaling, c.spin_launch_angle_y,
			c.spin_startup_ticks, c.spin_active_ticks, c.spin_recovery_ticks, c.hitstop_heavy)


func contacts(f: Fighter, fighters: Array[Fighter], a: AttackData, c: GameConfig) -> Array[Dictionary]:
	if not a.is_active(f.attack_ticks):
		return []
	return SpecialHits.radial(f, fighters, a, c.spin_radius, c)


func reach(c: GameConfig) -> float:
	return c.spin_radius
