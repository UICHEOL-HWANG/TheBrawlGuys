class_name Actions
extends RefCounted
## Control-state transitions (PRD §4.3): what a fighter that can act starts this tick and how a
## running attack advances (light combo, heavy charge, guard, grab attempts and bat swings).
## Motion owns physics and calls into here.


## Returns true when the fighter started an action this tick (movement is then skipped).
## Priority: grab > dodge (guard press + move input, or in the air) > guard > heavy > light.
static func try_start(f: Fighter, input: InputFrame, config: GameConfig) -> bool:
	if input.grab and f.on_ground:
		start_attack(f, AttackSet.Kind.GRAB)
		return true
	if Dodge.try_start(f, input, config):
		return true
	if input.guard and f.on_ground:
		f.set_state(Fighter.State.GUARD)
		f.state_ticks = 0
		stop_horizontal(f)
		return true
	if input.heavy:
		f.set_state(Fighter.State.CHARGE)
		f.state_ticks = 0
		f.charge_ticks = 0
		if f.on_ground:
			stop_horizontal(f)
		return true
	if input.light:
		if Item.is_melee(f.item_kind):
			start_attack(f, Item.MELEE_ATTACKS[f.item_kind])
			f.item_uses -= 1
			if f.item_uses <= 0:
				f.item_kind = Fighter.NONE
				f.item_uses = 0
		else:
			start_attack(f, AttackSet.Kind.LIGHT_1)
		return true
	return false


static func start_attack(f: Fighter, kind: int) -> void:
	f.set_state(Fighter.State.ATTACK)
	f.state_ticks = 0
	f.attack_kind = kind
	f.attack_ticks = 0
	f.combo_queued = false
	f.charge_mul = 1.0
	f.hit_ids.clear()
	if f.on_ground:
		stop_horizontal(f)


## One tick of a running attack. A light press while at most combo_buffer_ticks remain queues
## the next light hit, which starts on the tick this one ends (context E2).
static func step_attack(f: Fighter, input: InputFrame, config: GameConfig, attacks: AttackSet) -> void:
	var attack := attacks.get_attack(f.attack_kind)
	f.attack_ticks += 1
	if f.on_ground:
		stop_horizontal(f)
	var left := attack.total_ticks() - f.attack_ticks
	if input.light and AttackSet.is_light_chainable(f.attack_kind) and left <= config.combo_buffer_ticks:
		f.combo_queued = true
	if left > 0:
		return
	if f.combo_queued:
		start_attack(f, f.attack_kind + 1)
		return
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


## heavy is a held level (context E3): charge while it is true, swing on the tick it goes false.
static func step_charge(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	if f.on_ground:
		stop_horizontal(f)
	if input.heavy:
		f.charge_ticks = mini(f.charge_ticks + 1, SimTime.to_ticks(config.heavy_charge_max_time))
		return
	var mul := charge_mul(f.charge_ticks, config)
	start_attack(f, AttackSet.Kind.HEAVY)
	f.charge_mul = mul


## Guard holds while guard is pressed and the fighter stands on the ground (context E4). A
## guard push (guard_knockback_mul > 0) slides out with the ground friction.
static func step_guard(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	f.vel.x *= config.hitstun_ground_friction
	f.vel.z *= config.hitstun_ground_friction
	if not input.guard or not f.on_ground:
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


static func charge_mul(charge_ticks: int, config: GameConfig) -> float:
	var full := maxi(SimTime.to_ticks(config.heavy_charge_max_time), 1)
	return 1.0 + (config.heavy_charge_max_mul - 1.0) * minf(float(charge_ticks) / full, 1.0)


static func stop_horizontal(f: Fighter) -> void:
	f.vel.x = 0.0
	f.vel.z = 0.0
