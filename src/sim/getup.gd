class_name Getup
extends RefCounted
## Getting up (combat-depth C, PRD §4.3): state GETUP, entered from KNOCKDOWN (Knockdown.step)
## or straight from a tumbling landing as a tech (Knockdown.land). Kinds: STAND (in place),
## ROLL (along getup_dir like a Dodge roll), ATTACK (hits every foe around once after an
## intangible startup), TECH (in place) and TECH_ROLL. Each is intangible from its start for its
## kind's window, then ends in IDLE (AIR if it left the floor). Events on the start tick:
## "getup" {fighter, kind: stand|roll|attack} and "tech" {fighter, kind: place|roll}.

enum Kind { NONE, STAND, ROLL, ATTACK, TECH, TECH_ROLL }

## View names (FighterViewData "getup").
const KIND_NAMES := {
	Kind.STAND: "stand", Kind.ROLL: "roll", Kind.ATTACK: "attack", Kind.TECH: "tech", Kind.TECH_ROLL: "tech_roll",
}
## Kind -> [event type, event kind].
const EVENTS := {
	Kind.STAND: ["getup", "stand"], Kind.ROLL: ["getup", "roll"], Kind.ATTACK: ["getup", "attack"],
	Kind.TECH: ["tech", "place"], Kind.TECH_ROLL: ["tech", "roll"],
}


static func start(f: Fighter, kind: int, dir: Vector3, config: GameConfig) -> void:
	f.set_state(Fighter.State.GETUP)
	f.getup_kind = kind
	f.getup_ticks = 0
	f.getup_dir = dir
	f.hitstun_ticks = 0
	f.hit_ids.clear()
	_drive(f, config)


## Motion's step for a fighter in GETUP.
static func step(f: Fighter, config: GameConfig) -> void:
	f.getup_ticks += 1
	if not f.on_ground:
		_finish(f)  # rolled off the floor (or bounced): it can recover in the air
		return
	_drive(f, config)
	if f.getup_ticks >= total_ticks(f.getup_kind, config):
		_finish(f)


static func total_ticks(kind: int, config: GameConfig) -> int:
	match kind:
		Kind.STAND:
			return config.getup_stand_ticks
		Kind.TECH:
			return config.tech_ticks
		Kind.ATTACK:
			return attack_of(config).total_ticks()
	return config.getup_roll_move_ticks + config.getup_roll_recovery_ticks


## The getup attack's numbers (its hitstop is a light hit's).
static func attack_of(config: GameConfig) -> AttackData:
	return AttackData.make(config.getup_attack_damage, config.getup_attack_base_knockback,
			config.getup_attack_knockback_scaling, config.getup_attack_launch_angle_y,
			config.getup_attack_startup_ticks, config.getup_attack_active_ticks,
			config.getup_attack_recovery_ticks, config.hitstop_light)


## "" unless the fighter is getting up.
static func name_of(f: Fighter) -> String:
	return String(KIND_NAMES.get(f.getup_kind, "")) if f.state == Fighter.State.GETUP else ""


## Getup and tech events for every fighter that started one this tick.
static func started_events(advanced: Array[Fighter]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in advanced:
		if f.state == Fighter.State.GETUP and f.getup_ticks == 0 and EVENTS.has(f.getup_kind):
			var e: Array = EVENTS[f.getup_kind]
			events.append({"type": e[0], "fighter": f.id, "kind": e[1]})
	return events


## Before melee combat: the getup attacks' contacts this tick (start-of-combat state).
static func contacts(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for f: Fighter in fighters:
		if f.state != Fighter.State.GETUP or f.getup_kind != Kind.ATTACK:
			continue
		var attack := attack_of(config)
		if attack.is_active(f.getup_ticks):
			found.append_array(SpecialHits.radial(f, fighters, attack, config.getup_attack_radius, config))
	return found


## After melee combat: every getup attack contact lands ("hit" / "guard_hit" events).
static func apply(found: Array[Dictionary], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for h: Dictionary in found:
		var attacker: Fighter = h["attacker"]
		var target: Fighter = h["target"]
		var attack: AttackData = h["attack"]
		if not target.is_alive():
			continue
		events.append(Combat.apply_hit(target, attack, h["dir"], 1.0, config, h["at"], attacker.id))
		attacker.hit_ids.append(target.id)
		attacker.hitstop_ticks = maxi(attacker.hitstop_ticks, attack.hitstop_ticks)
	return events


## A hit, grab or respawn ends a getup.
static func clear(f: Fighter) -> void:
	f.getup_kind = Kind.NONE
	f.getup_ticks = 0


## Velocity and intangibility for the current getup tick.
static func _drive(f: Fighter, config: GameConfig) -> void:
	var rolling := f.getup_kind == Kind.ROLL or f.getup_kind == Kind.TECH_ROLL
	var moving := rolling and f.getup_ticks < config.getup_roll_move_ticks
	var speed := config.getup_roll_distance / (config.getup_roll_move_ticks * SimTime.TICK_DT)
	var v := f.getup_dir * speed if moving else Vector3.ZERO
	f.vel.x = v.x
	f.vel.z = v.z
	f.intangible = f.getup_ticks < _intangible_ticks(f.getup_kind, config)


static func _intangible_ticks(kind: int, config: GameConfig) -> int:
	match kind:
		Kind.TECH, Kind.TECH_ROLL:
			return config.tech_intangible_ticks
		Kind.ATTACK:
			# ticks 0..startup + 1: through the first active tick (startup + 1), so it never trades
			return config.getup_attack_startup_ticks + 2
	return config.getup_intangible_ticks


static func _finish(f: Fighter) -> void:
	f.getup_kind = Kind.NONE
	f.intangible = false
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)
