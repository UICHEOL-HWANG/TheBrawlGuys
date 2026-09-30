class_name GroundSlam
extends Special
## Barbarian "대지 강타" (ground slam): winds up, then pounds the ground; on its active ticks
## every foe level with him inside slam_radius is launched up and away (radial knockback).

const ID := "ground_slam"


func attack(c: GameConfig) -> AttackData:
	return AttackData.make(c.slam_damage, c.slam_base_knockback, c.slam_knockback_scaling, c.slam_launch_angle_y,
			c.slam_startup_ticks, c.slam_active_ticks, c.slam_recovery_ticks, c.hitstop_heavy)


func contacts(f: Fighter, fighters: Array[Fighter], a: AttackData, c: GameConfig) -> Array[Dictionary]:
	if not a.is_active(f.attack_ticks):
		return []
	return SpecialHits.radial(f, fighters, a, c.slam_radius, c)


func reach(c: GameConfig) -> float:
	return c.slam_radius
