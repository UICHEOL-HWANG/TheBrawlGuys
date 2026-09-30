class_name Dodge
extends RefCounted
## Rolls and air dodges (combat-depth A, PRD §4.3). No button of their own: the tick guard is
## newly pressed (GuardMeter.track_presses sets guard_press_age = 0) decides. On the ground with a
## move input it rolls along it; in the air it air-dodges along it (in place when neutral), once
## per airtime. The heavy+guard chord never dodges (special, else guard). A dodge is state DODGE:
## it moves at a fixed speed for its move ticks, is intangible (Fighter.untouchable) inside its
## window, then recovers. Rolls started within roll_spam_window_ticks of the last one add
## recovery (anti-spam). Landing, getting hit and respawning give the air dodge back. A roll
## that carries the fighter off the floor ends at once (AIR: it can jump back).

enum Kind { NONE, ROLL, AIR }

const KIND_NAMES := {Kind.ROLL: "roll", Kind.AIR: "air"}


## From Actions.try_start (fighter can act): true when a dodge started this tick.
static func try_start(f: Fighter, input: InputFrame, config: GameConfig) -> bool:
	if f.guard_press_age != 0 or not input.guard or input.heavy:
		return false
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	dir = dir.normalized() if dir.length_squared() > 0.0 else Vector3.ZERO
	if f.on_ground:
		if dir == Vector3.ZERO:
			return false  # neutral: a plain guard
		_start(f, Kind.ROLL, dir, config)
		return true
	if f.air_dodge_used:
		return false
	f.air_dodge_used = true
	_start(f, Kind.AIR, dir, config)
	return true


## Motion's step for a fighter in DODGE.
static func step(f: Fighter, config: GameConfig) -> void:
	f.dodge_ticks += 1
	# an air dodge ends on landing, a roll that left the floor ends so the fighter can recover
	if (f.dodge_kind == Kind.AIR) == f.on_ground:
		f.vel.x = 0.0
		f.vel.z = 0.0
		_finish(f, config)
		return
	_drive(f, config)
	if f.dodge_ticks >= f.dodge_total:
		_finish(f, config)


## Every advancing tick outside a dodge: the roll-spam window runs out.
static func cool(f: Fighter) -> void:
	if f.state != Fighter.State.DODGE and f.roll_recent > 0:
		f.roll_recent -= 1
		if f.roll_recent == 0:
			f.roll_streak = 0


## "dodge" {fighter, kind, dir} for every fighter that started one this tick.
static func started_events(advanced: Array[Fighter]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in advanced:
		if f.state == Fighter.State.DODGE and f.dodge_ticks == 0:
			events.append({"type": "dodge", "fighter": f.id, "kind": KIND_NAMES[f.dodge_kind], "dir": f.dodge_dir})
	return events


## Clears a dodge (hit, grab, respawn); the air dodge comes back.
static func clear(f: Fighter) -> void:
	f.dodge_kind = Kind.NONE
	f.dodge_ticks = 0
	f.intangible = false
	f.air_dodge_used = false


static func _start(f: Fighter, kind: int, dir: Vector3, config: GameConfig) -> void:
	f.set_state(Fighter.State.DODGE)
	f.dodge_kind = kind
	f.dodge_dir = dir
	f.dodge_ticks = 0
	if kind == Kind.ROLL:
		f.roll_streak = mini(f.roll_streak + 1, config.roll_spam_max_stack) if f.roll_recent > 0 else 0
		f.dodge_total = config.roll_move_ticks + config.roll_recovery_ticks \
				+ f.roll_streak * config.roll_spam_recovery_ticks
	else:
		f.dodge_total = config.air_dodge_move_ticks + config.air_dodge_recovery_ticks
	_drive(f, config)


## Velocity and intangibility for the current dodge tick.
static func _drive(f: Fighter, config: GameConfig) -> void:
	var roll := f.dodge_kind == Kind.ROLL
	var move_ticks := config.roll_move_ticks if roll else config.air_dodge_move_ticks
	var distance := config.roll_distance if roll else config.air_dodge_distance
	var start := config.roll_intangible_start if roll else config.air_dodge_intangible_start
	var window := config.roll_intangible_ticks if roll else config.air_dodge_intangible_ticks
	var moving := f.dodge_ticks < move_ticks
	var v := f.dodge_dir * (distance / (move_ticks * SimTime.TICK_DT)) if moving else Vector3.ZERO
	f.vel.x = v.x
	f.vel.z = v.z
	if not roll and moving:
		f.vel.y = 0.0  # the air burst hovers; gravity returns for the recovery
	f.intangible = f.dodge_ticks >= start and f.dodge_ticks < start + window


static func _finish(f: Fighter, config: GameConfig) -> void:
	if f.dodge_kind == Kind.ROLL:
		f.roll_recent = config.roll_spam_window_ticks
	f.dodge_kind = Kind.NONE
	f.intangible = false
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)
