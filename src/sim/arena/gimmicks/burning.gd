class_name Burning
extends RefCounted
## Burning status on a fighter (PRD-ARENA-01 campfire). Touching fire ignites (or refreshes) it
## for burn_duration and deals burn_damage at once; while it lasts it deals burn_damage every
## burn_interval. Damage adds to the % only (no knockback or hitstun). Runs before the gimmicks
## each tick so a fresh ignition waits a full interval for its next damage.


## Sets fighter f burning (not while untouchable: respawn, special or a dodge window); returns the gimmick_damage event of a fresh ignition, or {}.
static func ignite(f: Fighter, config: GameConfig) -> Dictionary:
	if not f.is_alive() or f.untouchable():
		return {}
	var fresh := f.burn_ticks <= 0
	f.burn_ticks = maxi(SimTime.to_ticks(config.burn_duration), 1)
	if not fresh:
		return {}
	f.burn_clock = 0
	return _damage(f, config)


static func step(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var interval := maxi(SimTime.to_ticks(config.burn_interval), 1)
	for f: Fighter in fighters:
		if f.burn_ticks <= 0:
			continue
		if not f.is_alive():
			f.burn_ticks = 0
			continue
		f.burn_ticks -= 1
		if f.burn_ticks == 0:
			continue
		f.burn_clock += 1
		if f.burn_clock >= interval:
			f.burn_clock = 0
			events.append(_damage(f, config))
	return events


static func _damage(f: Fighter, config: GameConfig) -> Dictionary:
	f.damage += config.burn_damage
	return {"type": "gimmick_damage", "kind": "burn", "target": f.id, "amount": config.burn_damage, "pos": f.pos}
