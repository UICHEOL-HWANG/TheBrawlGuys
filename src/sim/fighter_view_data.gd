class_name FighterViewData
extends RefCounted
## A fighter's view dictionary (value copies only, PRD §5.2). Phase 5 adds "character",
## "style", "special" (ids, "" = none) and "gauge" (0..SpecialGauge.MAX); a special in progress
## is state SPECIAL with attack_kind SPECIAL and attack_ticks counting from its start.
## Combat-depth A adds "is_dodging" (intangible right now), "guard_hp_ratio" (0..1) and
## "guard_broken" (stunned by a guard break).


static func of(f: Fighter) -> Dictionary:
	return {
		"id": f.id, "spawn_id": f.spawn_id, "pos": f.pos, "facing": f.facing, "state": f.state,
		"on_ground": f.on_ground, "damage": f.damage, "stocks": f.stocks, "jumps_left": f.jumps_left,
		"invuln_ticks": f.invuln_ticks, "hitstop_ticks": f.hitstop_ticks, "attack_ticks": f.attack_ticks,
		"attack_kind": f.attack_kind, "charge_ticks": f.charge_ticks, "partner_id": f.partner_id,
		"item_kind": f.item_kind, "item_uses": f.item_uses, "burning": f.burn_ticks > 0,
		"character": f.character, "style": CharacterData.style_of(f.character),
		"special": CharacterData.special_of(f.character), "gauge": f.gauge,
		"is_dodging": f.intangible, "guard_hp_ratio": f.guard_hp / GuardMeter.MAX,
		"guard_broken": f.guard_break_left > 0,
	}
