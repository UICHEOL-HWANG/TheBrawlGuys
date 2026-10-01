class_name DashRush
extends Special
## Rogue "돌진 연타" (dash rush): after a short windup he dashes forward at rush_speed for the
## active ticks, hitting whoever is in front every rush_hit_interval ticks (small link hits that
## hold hitstun and carry the foe along); a hit in the last interval is the launcher.

const ID := "dash_rush"


func attack(c: GameConfig) -> AttackData:
	var a := AttackData.make(c.rush_damage, c.rush_base_knockback, 0.0, 0.0,
			c.rush_startup_ticks, c.rush_active_ticks, c.rush_recovery_ticks, c.hitstop_light)
	a.min_hitstun_ticks = c.rush_hitstun_ticks
	a.hitbox_forward = c.rush_hitbox_forward
	a.hitbox_up = c.light_hitbox_up
	a.hitbox_half = Vector3(c.rush_hitbox_half_width, c.light_hitbox_half_height, c.rush_hitbox_half_width)
	return a


func finisher(c: GameConfig) -> AttackData:
	return AttackData.make(c.rush_finish_damage, c.rush_finish_base_knockback, c.rush_finish_knockback_scaling,
			c.rush_finish_launch_angle_y, 0, 1, 0, c.hitstop_heavy)


func move(f: Fighter, a: AttackData, c: GameConfig) -> void:
	if a.is_active(f.attack_ticks):
		f.vel.x = f.facing.x * c.rush_speed
		f.vel.z = f.facing.z * c.rush_speed
	elif f.on_ground:
		Actions.stop_horizontal(f)


## Each new interval may hit the same foe again.
func advance(f: Fighter, a: AttackData, _field: ProjectileField, c: GameConfig) -> Array[Dictionary]:
	if a.is_active(f.attack_ticks) and (f.attack_ticks - a.startup_ticks - 1) % c.rush_hit_interval == 0:
		f.hit_ids.clear()
	return []


func contacts(f: Fighter, fighters: Array[Fighter], a: AttackData, c: GameConfig) -> Array[Dictionary]:
	if not a.is_active(f.attack_ticks):
		return []
	var window := floori(float(f.attack_ticks - a.startup_ticks - 1) / c.rush_hit_interval)
	var last := window == floori(float(a.active_ticks - 1) / c.rush_hit_interval)
	var numbers := finisher(c) if last else a
	var center := Combat.hitbox_center(f, a)
	var yaw := Collision.yaw_of(f.facing)
	var found: Array[Dictionary] = []
	for t: Fighter in fighters:
		if t == f or not t.is_alive() or t.untouchable_by(f.id) or f.hit_ids.has(t.id):
			continue
		if Collision.capsule_hits_box(t.pos, c.fighter_radius, c.fighter_height, center, yaw, a.hitbox_half):
			found.append(SpecialHits.contact(f, t, numbers, f.facing, center))
	return found


func reach(c: GameConfig) -> float:
	return c.rush_speed * SimTime.TICK_DT * c.rush_active_ticks + c.rush_hitbox_forward
