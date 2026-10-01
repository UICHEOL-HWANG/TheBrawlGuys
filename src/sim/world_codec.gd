class_name WorldCodec
extends RefCounted
## World snapshot bytes (PRD-ARCH-04), split out of World. The config fingerprint is part of
## every snapshot (context D1). v3 added the Phase 2 fighter fields, v4 the item field, v5 the
## arena state and burn fields (Phase 4), v6 the fighter character and special gauge and the
## projectile field (Phase 5), v7 the fighter dodge and guard-meter fields (combat-depth A), v8
## guard_rest_ticks (perfect-guard rearm), v9 the knockdown / getup / tech / DI fields (combat-depth C),
## v10 the match mode state and fighter ally_mask (combat-depth D).

const VERSION := 10
const TYPES := {
	"tick": TYPE_INT, "rng_seed": TYPE_INT, "rng_state": TYPE_INT, "config_fp": TYPE_INT,
	"match_over": TYPE_BOOL, "winner": TYPE_INT, "fighters": TYPE_ARRAY,
	"items": TYPE_DICTIONARY, "arena": TYPE_DICTIONARY, "projectiles": TYPE_DICTIONARY,
	"mode": TYPE_DICTIONARY,
}


static func encode(w: World, rng: RandomNumberGenerator) -> PackedByteArray:
	var data: Array[Dictionary] = []
	for f: Fighter in w.fighters:
		data.append(f.to_data())
	return var_to_bytes({
		"v": VERSION, "tick": w.tick_count, "rng_seed": rng.seed, "rng_state": rng.state,
		"config_fp": w.config.fingerprint(), "match_over": w.match_over, "winner": w.winner_id,
		"fighters": data, "items": w.items.to_data(), "arena": w.arena.to_data(),
		"projectiles": w.projectiles.to_data(), "mode": w.mode_state.to_data(),
	})


## The restored pieces {"s": raw snapshot, "fighters", "items", "arena", "projectiles", "mode"} when the
## snapshot fits World w, else {} (with an error pushed).
static func decode(w: World, data: PackedByteArray) -> Dictionary:
	var s := _checked(w, data)
	if s.is_empty():
		return {}
	var restored: Array[Fighter] = []
	for d: Variant in s["fighters"]:
		var f: Fighter = Fighter.from_data(d) if d is Dictionary else null
		if f == null:
			return _fail("invalid fighter data")
		restored.append(f)
	var items := ItemField.from_data(s["items"])
	if items == null:
		return _fail("invalid item data")
	var projectiles := ProjectileField.from_data(s["projectiles"])
	if projectiles == null:
		return _fail("invalid projectile data")
	if not _consistent(restored, projectiles):
		return _fail("inconsistent fighter or projectile data")
	var mode := ModeState.from_data(s["mode"], restored.size())
	if mode == null:
		return _fail("invalid mode data")
	var arena := w.arena.copy()
	if not arena.load_data(s["arena"]):
		return _fail("invalid arena data")
	return {"s": s, "fighters": restored, "items": items, "arena": arena, "projectiles": projectiles,
		"mode": mode}


## The snapshot dictionary when version, keys, config and arena match w, else {}.
static func _checked(w: World, data: PackedByteArray) -> Dictionary:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != VERSION:
		return _fail("incompatible snapshot")
	var s: Dictionary = decoded
	for key: String in TYPES:
		if not s.has(key) or typeof(s[key]) != TYPES[key]:
			return _fail("incomplete snapshot")
	if s["config_fp"] != w.config.fingerprint():
		return _fail("config mismatch")
	if (s["arena"] as Dictionary).get("id") != w.arena.id:
		return _fail("arena mismatch")
	return s


## Values later used as indices stay in range: fighter ids are their slots, states / attack kinds
## are known enum values, gauges and guard meters are 0..MAX, a perfect guard names a fighter,
## projectiles belong to a fighter and use known kinds.
static func _consistent(fighters: Array[Fighter], projectiles: ProjectileField) -> bool:
	for i: int in fighters.size():
		var f := fighters[i]
		if f.id != i or not _in_enum(f.state, Fighter.State) or not _in_enum(f.attack_kind, AttackSet.Kind) \
				or not (f.gauge >= 0.0 and f.gauge <= SpecialGauge.MAX) or not _defense_ok(f, fighters.size()):
			return false
	for p: Projectile in projectiles.list:
		if p.owner_id < 0 or p.owner_id >= fighters.size() or not _in_enum(p.kind, Projectile.Kind) \
				or not _in_enum(p.attack_kind, AttackSet.Kind):
			return false
	return true


static func _defense_ok(f: Fighter, count: int) -> bool:
	return f.guard_hp >= 0.0 and f.guard_hp <= GuardMeter.MAX and _in_enum(f.dodge_kind, Dodge.Kind) \
			and f.perfect_by >= Fighter.NONE and f.perfect_by < count and _in_enum(f.getup_kind, Getup.Kind) \
			and f.tech_clock >= 0


static func _in_enum(value: int, e: Dictionary) -> bool:
	return value >= 0 and value < e.size()


static func _fail(reason: String) -> Dictionary:
	push_error("World.restore: " + reason)
	return {}
