class_name Knockdown
extends RefCounted
## Knockdown (combat-depth C, PRD §4.3). A clean hit of at least knockdown_min_knockback that
## sends the target up makes it tumble (Fighter.tumble; jumping, attacking or dodging ends it).
## A tumbling fighter touching down lies in KNOCKDOWN, unless a tech is armed (Tech): then it
## techs in place, or tech-rolls along the stick. Lying fighters can be hit, for
## knockdown_hit_knockback_mul of the knockback and never tumbling again (no lock). After
## knockdown_min_ticks of lying: light = getup attack, a direction = getup roll, jump or guard =
## stand up; after knockdown_ticks it stands up by itself (Getup). Event: "knockdown" {fighter, pos}.


## Motion.step, on the tick a tumbling fighter touches down.
static func land(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	f.hitstun_ticks = 0
	if Tech.armed(f, config):
		f.tech_clock = 0
		var dir := stick(input)
		Getup.start(f, Getup.Kind.TECH if dir == Vector3.ZERO else Getup.Kind.TECH_ROLL, dir, config)
		return
	f.set_state(Fighter.State.KNOCKDOWN)


## Motion's step for a lying fighter. state_ticks counts the ticks it has lain so far; friction is
## the floor's slide friction (GroundGrip.friction).
static func step(f: Fighter, input: InputFrame, config: GameConfig, friction: float) -> void:
	if not f.on_ground:
		f.set_state(Fighter.State.AIR)  # the floor went away (a breaking plank, a mushroom)
		return
	f.vel.x *= friction
	f.vel.z *= friction
	if f.state_ticks >= config.knockdown_ticks:
		Getup.start(f, Getup.Kind.STAND, Vector3.ZERO, config)
		return
	if f.state_ticks < config.knockdown_min_ticks:
		return
	var dir := stick(input)
	if input.light:
		Getup.start(f, Getup.Kind.ATTACK, Vector3.ZERO, config)
	elif dir != Vector3.ZERO:
		Getup.start(f, Getup.Kind.ROLL, dir, config)
	elif input.jump or input.guard:
		Getup.start(f, Getup.Kind.STAND, Vector3.ZERO, config)


## Knockback multiplier for a hit on target (reduced while it lies down).
static func hit_mul(target: Fighter, config: GameConfig) -> float:
	return config.knockdown_hit_knockback_mul if target.state == Fighter.State.KNOCKDOWN else 1.0


## Whether a clean hit of knockback kb that set vel makes its target tumble.
static func tumbles(kb: float, vel: Vector3, was_lying: bool, config: GameConfig) -> bool:
	return not was_lying and vel.y > 0.0 and kb >= config.knockdown_min_knockback


## "knockdown" for every fighter that lay down this tick, then the getup / tech starts.
static func started_events(advanced: Array[Fighter]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in advanced:
		if f.state == Fighter.State.KNOCKDOWN and f.state_ticks == 1:
			events.append({"type": "knockdown", "fighter": f.id, "pos": f.pos})
	events.append_array(Getup.started_events(advanced))
	return events


## The move stick as a flat unit direction (zero when neutral).
static func stick(input: InputFrame) -> Vector3:
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	return dir.normalized() if dir.length_squared() > 0.0 else Vector3.ZERO
