class_name CombatSounds
extends RefCounted
## Combat events -> {"name", "pitch", "volume_db"} (design.md DS-SFX-01): projectile launches
## (bolts zap, the fireball roars), their pops and booms, the special's power-up sting, grabs
## and melee swing whooshes (ViewEvents "swing"). {} = silent. Sounds: CombatSfxRecipes.

## A bolt that fizzles out instead of landing is this much quieter.
const FIZZLE_DB := -7.0
const POP_DB := -3.0
const HEAVY_BOLT_PITCH := 0.8
## Repeated projectiles step through a few nearby pitches (by id) so a volley does not drone.
const PITCH_STEP := 0.025
const PITCH_SPREAD := 5
const PITCH_CENTER := 2
## Each special's charge sting in its own color: the slam deep, the rush bright.
const SPECIAL_PITCH := {
	SpecialCatalog.GROUND_SLAM: 0.8, SpecialCatalog.DASH_RUSH: 1.15,
	SpecialCatalog.SPIN_SLASH: 1.0, SpecialCatalog.BIG_FIREBALL: 0.9,
}
const LAUNCH := {
	Projectile.Kind.BOLT: "zap_bolt", Projectile.Kind.HEAVY_BOLT: "zap_heavy",
	Projectile.Kind.FIREBALL: "fireball_launch",
}
## Swings: item kind -> pitch of the blade swish (a bat or hammer is a heavy swish).
const ITEM_SWING_PITCH := {AttackSet.Kind.BAT: 0.72, AttackSet.Kind.HAMMER: 0.8}
## Combo hits step the pitch a little so a chain does not repeat one whoosh.
const LIGHT_SWING_PITCH := {AttackSet.Kind.LIGHT_1: 1.0, AttackSet.Kind.LIGHT_2: 1.07, AttackSet.Kind.LIGHT_3: 0.94}
const HEAVY_SWING_PITCH := 0.76
const HEAVY_SWING_DB := 2.0


static func for_event(event: Dictionary) -> Dictionary:
	match String(event["type"]):
		"projectile_spawn":
			var kind := int(event.get("kind", Projectile.Kind.BOLT))
			return _sound(String(LAUNCH.get(kind, "zap_bolt")), _spread(event), 0.0)
		"projectile_hit", "projectile_expire":
			return _projectile_end(event)
		"special_start":
			return _sound("special_charge", float(SPECIAL_PITCH.get(String(event.get("special", "")), 1.0)), 0.0)
		"grab", "grab_release":
			return _sound(String(event["type"]), 1.0, 0.0)
		"swing":
			return swing(String(event.get("style", "")), int(event.get("kind", AttackSet.Kind.LIGHT_1)))
	return {}


static func _projectile_end(event: Dictionary) -> Dictionary:
	var kind := int(event.get("kind", Projectile.Kind.BOLT))
	if kind == Projectile.Kind.FIREBALL:
		return _sound("fireball_boom", 1.0, 0.0)  # it bursts whether it hit or ran out
	var pitch := _spread(event) * (HEAVY_BOLT_PITCH if kind == Projectile.Kind.HEAVY_BOLT else 1.0)
	return _sound("bolt_pop", pitch, FIZZLE_DB if String(event["type"]) == "projectile_expire" else POP_DB)


## A melee swing's whoosh: items and the knight's sword swish, fists push air; casts are silent.
static func swing(style: String, kind: int) -> Dictionary:
	if ITEM_SWING_PITCH.has(kind):
		return _sound("swing_blade", float(ITEM_SWING_PITCH[kind]), HEAVY_SWING_DB)
	if style == StyleCatalog.RANGED:
		return {}  # a bolt cast: the zap covers it
	var name := "swing_blade" if style == StyleCatalog.WEAPON else "swing_air"
	if kind == AttackSet.Kind.HEAVY:
		return _sound(name, HEAVY_SWING_PITCH, HEAVY_SWING_DB)
	return _sound(name, float(LIGHT_SWING_PITCH.get(kind, 1.0)), 0.0)


static func _spread(event: Dictionary) -> float:
	return 1.0 + float(posmod(int(event.get("id", 0)), PITCH_SPREAD) - PITCH_CENTER) * PITCH_STEP


static func _sound(name: String, pitch: float, volume_db: float) -> Dictionary:
	return {"name": name, "pitch": pitch, "volume_db": volume_db}
