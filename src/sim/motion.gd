class_name Motion
extends RefCounted
## Per-tick fighter movement (PRD §4): input -> state, gravity, landing, walking off the edge,
## and capsule separation. Hitstop freezes a fighter completely (PRD §4.2).

## A fighter may land only if it was at most this far below the floor on the previous tick,
## so a fighter falling under the arena never snaps back up.
const LAND_TOLERANCE := 0.05


static func step(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void:
	if not f.is_alive():
		return
	if f.hitstop_ticks > 0:
		f.hitstop_ticks -= 1
		return
	if f.invuln_ticks > 0:
		f.invuln_ticks -= 1
	match f.state:
		Fighter.State.HITSTUN:
			_step_hitstun(f, config)
		Fighter.State.ATTACK:
			Actions.step_attack(f, input, config, attacks)
		_:
			if not Actions.try_start(f, input, config):
				_step_control(f, input, config)
	_integrate(f, config)
	f.state_ticks += 1


static func separate(fighters: Array[Fighter], config: GameConfig) -> void:
	for i: int in fighters.size():
		for j: int in range(i + 1, fighters.size()):
			var a := fighters[i]
			var b := fighters[j]
			if not a.is_alive() or not b.is_alive():
				continue
			var push := Collision.separate_capsules(a.pos, b.pos, config.fighter_radius, config.fighter_height)
			a.pos += push
			b.pos -= push


static func _step_control(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if input.jump and f.jumps_left > 0:
		f.vel.y = config.jump_velocity
		f.jumps_left -= 1
		f.on_ground = false
	var target := Vector2(dir.x, dir.z) * config.move_speed
	if f.on_ground:
		f.vel.x = target.x
		f.vel.z = target.y
	else:
		# airborne: steer toward the input, or drift with light drag, never snap to zero
		var accel := config.air_acceleration if dir.length_squared() > 0.0 else config.air_drag
		var flat := Vector2(f.vel.x, f.vel.z).move_toward(target, accel * SimTime.TICK_DT)
		f.vel.x = flat.x
		f.vel.z = flat.y
	if dir.length_squared() > 0.0:
		f.facing = dir.normalized()
	if not f.on_ground:
		f.set_state(Fighter.State.AIR)
	elif dir.length_squared() > 0.0:
		f.set_state(Fighter.State.MOVE)
	else:
		f.set_state(Fighter.State.IDLE)


static func _step_hitstun(f: Fighter, config: GameConfig) -> void:
	f.hitstun_ticks -= 1
	if f.on_ground:
		f.vel.x *= config.hitstun_ground_friction
		f.vel.z *= config.hitstun_ground_friction
	if f.hitstun_ticks <= 0:
		f.hitstun_ticks = 0
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func _integrate(f: Fighter, config: GameConfig) -> void:
	var prev_y := f.pos.y
	f.vel.y += config.gravity * SimTime.TICK_DT
	f.pos += f.vel * SimTime.TICK_DT
	var over_floor := Collision.on_arena_floor(f.pos, config.arena_radius)
	if over_floor and f.pos.y <= 0.0 and prev_y >= -LAND_TOLERANCE and f.vel.y <= 0.0:
		f.pos.y = 0.0
		f.vel.y = 0.0
		if not f.on_ground:
			f.on_ground = true
			f.jumps_left = config.max_jumps
			if f.state == Fighter.State.AIR:
				f.set_state(Fighter.State.IDLE)
		return
	if f.on_ground:
		# walked off the edge: the ground jump is gone, air jumps remain
		f.jumps_left = mini(f.jumps_left, config.max_jumps - 1)
	f.on_ground = false
	if f.state == Fighter.State.IDLE or f.state == Fighter.State.MOVE:
		f.set_state(Fighter.State.AIR)
