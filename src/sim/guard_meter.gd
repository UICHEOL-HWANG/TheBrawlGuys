class_name GuardMeter
extends RefCounted
## Guard durability and perfect guard (combat-depth A, PRD §4.3). Each fighter has guard_hp out
## of MAX: guarding drains guard_hold_drain per tick and blocked hits guard_block_mul per point
## of their unscaled damage (Combat.apply_hit calls block); after guard_regen_delay_ticks without
## guarding it refills. At 0 while guarding the guard breaks: the fighter pops up and is stunned
## (HITSTUN, guard_break_left counts down for the view), hits on it land in full.
## A hit within perfect_guard_ticks of the guard press (guard_press_age) is a perfect guard: no
## chip damage, no guard points lost, and a melee attacker freezes perfect_guard_stagger_ticks
## longer. Events: guard_break {fighter, pos}, perfect_guard {fighter, attacker, pos}.

const MAX := 100.0
## guard_press_age stops counting here ("pressed long ago").
const AGE_CAP := 255


## Before any step, on the raw input copies: marks the tick guard is newly pressed (age 0).
static func track_presses(fighters: Array[Fighter], frame: Array[InputFrame]) -> void:
	for f: Fighter in fighters:
		var held := frame[f.id].guard
		f.guard_press_age = 0 if held and not f.guard_prev else mini(f.guard_press_age + 1, AGE_CAP)
		f.guard_prev = held


static func is_perfect(target: Fighter, config: GameConfig) -> bool:
	return target.state == Fighter.State.GUARD and target.guard_press_age <= config.perfect_guard_ticks


## A hit of `damage` (before guard scaling) was blocked by target.
static func block(target: Fighter, damage: float, config: GameConfig) -> void:
	target.guard_hp = maxf(target.guard_hp - damage * config.guard_block_mul, 0.0)


## After every hit this tick: perfect-guard staggers, hold drain, breaks and refills.
static func step(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.is_alive():
			continue
		if f.perfect_by != Fighter.NONE:
			events.append(_perfect(f, fighters, config))
		if f.guard_break_left > 0 and f.hitstop_ticks <= 0:
			f.guard_break_left -= 1
		if f.state == Fighter.State.GUARD:
			f.guard_idle_ticks = 0
			if f.hitstop_ticks <= 0:
				f.guard_hp = maxf(f.guard_hp - config.guard_hold_drain, 0.0)
			if f.guard_hp <= 0.0:
				events.append(_break(f, config))
		else:
			f.guard_idle_ticks = mini(f.guard_idle_ticks + 1, AGE_CAP)
			if f.guard_idle_ticks > config.guard_regen_delay_ticks:
				f.guard_hp = minf(f.guard_hp + config.guard_regen_per_tick, MAX)
	return events


## Back to a full, unbroken meter (respawn).
static func reset(f: Fighter) -> void:
	f.guard_hp = MAX
	f.guard_idle_ticks = 0
	f.guard_break_left = 0
	f.perfect_by = Fighter.NONE


static func _perfect(f: Fighter, fighters: Array[Fighter], config: GameConfig) -> Dictionary:
	var attacker := Grab.find(fighters, f.perfect_by)
	# melee only: Combat.resolve records the target in the swing's hit_ids (shots and blasts do not)
	if attacker != null and attacker.state == Fighter.State.ATTACK and attacker.hit_ids.has(f.id):
		attacker.hitstop_ticks += config.perfect_guard_stagger_ticks
	var e := {"type": "perfect_guard", "fighter": f.id, "attacker": f.perfect_by, "pos": f.pos}
	f.perfect_by = Fighter.NONE
	return e


static func _break(f: Fighter, config: GameConfig) -> Dictionary:
	f.set_state(Fighter.State.HITSTUN)
	f.hitstun_ticks = config.guard_break_stun_ticks
	f.guard_break_left = config.guard_break_stun_ticks
	f.guard_hp = config.guard_break_refill
	f.vel = Vector3(0.0, config.guard_break_pop_speed, 0.0)
	f.on_ground = false
	return {"type": "guard_break", "fighter": f.id, "pos": f.pos}
