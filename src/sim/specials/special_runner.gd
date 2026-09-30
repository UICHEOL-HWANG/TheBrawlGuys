class_name SpecialRunner
extends RefCounted
## Runs specials inside World.tick (PRD §6.2.1). A fighter whose character has a special, whose
## gauge is full and who holds heavy and guard on the same tick (X+C) starts it once from IDLE,
## MOVE, AIR, GUARD or CHARGE, or cancelling a dodge at most special_cancel_window ticks old (the
## chord's guard landed a tick before its heavy and started a roll): the gauge empties, it turns SPECIAL (attack_kind SPECIAL,
## attack_ticks from 0) and is invulnerable for special_invuln_ticks. It faces the move input
## when there is one (aim the rush or the fireball). Getting hit ends it.
## Events: special_start {fighter, character, special, pos}; hits come from SpecialHits.

const STARTABLE: Array[int] = [
	Fighter.State.IDLE, Fighter.State.MOVE, Fighter.State.AIR, Fighter.State.GUARD, Fighter.State.CHARGE,
]


## Before movement: starts specials and clears the spent heavy/guard from the input copies.
static func try_start(fighters: Array[Fighter], frame: Array[InputFrame], book: StyleBook,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		var input := frame[f.id]
		var kit := book.kit(f.id)
		if not can_start(f, input, kit.special, config):
			continue
		var aim := Vector3(input.move_x, 0.0, input.move_z)
		if aim.length_squared() > 0.0:
			f.facing = aim.normalized()
		start(f, config)
		input.heavy = false
		input.guard = false
		events.append({"type": "special_start", "fighter": f.id, "character": f.character,
				"special": kit.special, "pos": f.pos})
	return events


static func can_start(f: Fighter, input: InputFrame, special: String, config: GameConfig) -> bool:
	return not special.is_empty() and f.gauge >= SpecialGauge.MAX and input.heavy and input.guard \
			and f.hitstop_ticks <= 0 and f.is_alive() and (STARTABLE.has(f.state) or _fresh_dodge(f, config))


static func start(f: Fighter, config: GameConfig) -> void:
	if f.state == Fighter.State.DODGE:
		Dodge.cancel(f)
	Actions.start_attack(f, AttackSet.Kind.SPECIAL)
	f.set_state(Fighter.State.SPECIAL)
	f.charge_ticks = 0
	f.gauge = 0.0
	f.invuln_ticks = maxi(f.invuln_ticks, config.special_invuln_ticks)


static func _fresh_dodge(f: Fighter, config: GameConfig) -> bool:
	return f.state == Fighter.State.DODGE and f.dodge_ticks <= config.special_cancel_window


## Motion's step for a fighter in SPECIAL: advance the clock, move, end after the recovery.
static func step(f: Fighter, config: GameConfig, book: StyleBook) -> void:
	var attack := book.attacks(f.id).get_attack(AttackSet.Kind.SPECIAL)
	f.attack_ticks += 1
	SpecialCatalog.get_special(book.kit(f.id).special).move(f, attack, config)
	if f.attack_ticks >= attack.total_ticks():
		f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)


## Once per tick for fighters that advanced (not frozen): spawns and multi-hit windows.
static func advance(advanced: Array[Fighter], book: StyleBook, field: ProjectileField,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in advanced:
		if f.state == Fighter.State.SPECIAL:
			var attack := book.attacks(f.id).get_attack(AttackSet.Kind.SPECIAL)
			events.append_array(SpecialCatalog.get_special(book.kit(f.id).special).advance(f, attack, field, config))
	return events


## Before melee combat: every special's contacts this tick, from the start-of-step state.
static func contacts(fighters: Array[Fighter], book: StyleBook, config: GameConfig) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for f: Fighter in fighters:
		if f.state == Fighter.State.SPECIAL:
			var attack := book.attacks(f.id).get_attack(AttackSet.Kind.SPECIAL)
			found.append_array(SpecialCatalog.get_special(book.kit(f.id).special).contacts(f, fighters, attack, config))
	return found


## After melee combat: applies every contact (a special user hit this tick still lands its hit).
static func apply(found: Array[Dictionary], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for h: Dictionary in found:
		var target: Fighter = h["target"]
		if target.is_alive():
			events.append_array(SpecialHits.hit(h["attacker"], target, h["attack"], h["dir"], h["at"], config))
	return events
