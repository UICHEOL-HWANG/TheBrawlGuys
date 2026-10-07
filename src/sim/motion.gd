class_name Motion
extends RefCounted
## Per-tick fighter movement (PRD §4): input -> state, gravity, landing, walking off the edge,
## and capsule separation. Hitstop freezes a fighter completely (PRD §4.2). Floors come from the
## arena (ArenaFloor.ground_top), which also owns the landing tolerance. Run speed, jump and air
## control come from the fighter's style (StyleBook, Phase 5). Combat-depth C: the first tick after
## a hit's hitstop applies DI (LaunchInfluence); a tumbling fighter touching down is knocked down
## or techs (Knockdown), then gets up (Getup). The arena's floor grip (GroundGrip) shapes grounded
## walking and slides: ice eases toward the stick and slides farther.


## Returns true when the fighter advanced this tick (alive and not frozen in hitstop).
static func step(f: Fighter, input: InputFrame, config: GameConfig, book: StyleBook, arena: ArenaData) -> bool:
	if not f.is_alive():
		return false
	if f.hitstop_ticks > 0:
		f.hitstop_ticks -= 1
		return false
	if f.invuln_ticks > 0:
		f.invuln_ticks -= 1
	Dodge.cool(f)
	LaunchInfluence.apply(f, input, config)
	_step_state(f, input, config, book, arena)
	var tumbling := f.tumble and not f.on_ground
	if f.state != Fighter.State.HELD:
		_integrate(f, config, arena)
	if tumbling and f.on_ground:
		Knockdown.land(f, input, config)
	f.state_ticks += 1
	return true


static func _step_state(f: Fighter, input: InputFrame, config: GameConfig, book: StyleBook, arena: ArenaData) -> void:
	match f.state:
		Fighter.State.HITSTUN:
			_step_hitstun(f, GroundGrip.friction(config, arena))
		Fighter.State.ATTACK:
			Actions.step_attack(f, input, config, book.attacks(f.id))
		Fighter.State.CHARGE:
			Actions.step_charge(f, input, config)
		Fighter.State.GUARD:
			Actions.step_guard(f, input, config, GroundGrip.friction(config, arena))
		Fighter.State.SPECIAL:
			SpecialRunner.step(f, config, book)
		Fighter.State.DODGE:
			Dodge.step(f, config)
		Fighter.State.KNOCKDOWN:
			Knockdown.step(f, input, config, GroundGrip.friction(config, arena))
		Fighter.State.GETUP:
			Getup.step(f, config)
		Fighter.State.HOLDING, Fighter.State.HELD:
			pass  # Grab.step drives holds; the held fighter's position comes from the holder
		_:
			if not Actions.try_start(f, input, config):
				_step_control(f, input, config, book.kit(f.id).style, arena)


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


static func _step_control(f: Fighter, input: InputFrame, config: GameConfig, style: StyleData, arena: ArenaData) -> void:
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if input.jump and f.jumps_left > 0:
		f.vel.y = style.jump_velocity
		f.jumps_left -= 1
		f.on_ground = false
		f.tumble = false  # jumping out of a tumble lands on the feet
	var target := Vector2(dir.x, dir.z) * style.move_speed
	if f.on_ground:
		GroundGrip.walk(f, target, config, arena)
	else:
		# airborne: steer toward the input, or drift with light drag, never snap to zero
		var accel := style.air_acceleration if dir.length_squared() > 0.0 else config.air_drag
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


static func _step_hitstun(f: Fighter, friction: float) -> void:
	f.hitstun_ticks -= 1
	if f.on_ground:
		f.vel.x *= friction
		f.vel.z *= friction
	if f.hitstun_ticks <= 0:
		f.hitstun_ticks = 0
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func _integrate(f: Fighter, config: GameConfig, arena: ArenaData) -> void:
	var prev_y := f.pos.y
	f.vel.y += config.gravity * SimTime.TICK_DT
	f.pos += f.vel * SimTime.TICK_DT
	var top := ArenaFloor.ground_top(arena, f.pos, prev_y)
	if top != ArenaFloor.NO_GROUND and f.pos.y <= top and f.vel.y <= 0.0:
		f.pos.y = top
		f.vel.y = 0.0
		if not f.on_ground:
			f.on_ground = true
			f.jumps_left = config.max_jumps
			f.air_dodge_used = false
			if f.state == Fighter.State.AIR:
				f.set_state(Fighter.State.IDLE)
		return
	if f.on_ground:
		# walked off the edge: the ground jump is gone, air jumps remain
		f.jumps_left = mini(f.jumps_left, config.max_jumps - 1)
	f.on_ground = false
	if f.state == Fighter.State.IDLE or f.state == Fighter.State.MOVE:
		f.set_state(Fighter.State.AIR)
