class_name HitSounds
extends RefCounted
## Weapon hit sounds (design.md DS-SFX-01): a held or thrown item decides the sound first, then
## the attacker's style (boxer and classic punch, the knight's sword rings, the mage's bolts
## burst). Light or heavy follows the knockback, and the pitch drops as it grows.
## scripts/music/hits.py renders NAMES into assets/sfx/<name>.wav (bake_sfx.gd leaves them alone).

const LIGHT_VOLUME_DB := -4.0
const MIN_PITCH := 0.7
const MAX_PITCH := 1.2
const BASE_PITCH := 1.15
## Style -> [light, heavy] sound names; any other style punches.
const FAMILIES := {
	StyleCatalog.WEAPON: ["hit_sword_light", "hit_sword_heavy"],
	StyleCatalog.RANGED: ["hit_magic_light", "hit_magic_heavy"],
}
const FISTS: Array[String] = ["hit_light", "hit_heavy"]
## Item and grab attacks sound the same whoever swings them.
const ITEMS := {
	AttackSet.Kind.BAT: "hit_bat", AttackSet.Kind.ROCK: "hit_rock", AttackSet.Kind.GLOVE: "hit_feather",
	AttackSet.Kind.THROW: "hit_heavy", AttackSet.Kind.BOMB: "hit_heavy",
}
const NAMES: Array[String] = [
	"hit_light", "hit_heavy", "hit_sword_light", "hit_sword_heavy", "hit_magic_light", "hit_magic_heavy",
	"hit_bat", "hit_rock", "hit_feather",
]


## {"name", "pitch", "volume_db"} for a "hit" event; attacker_style is "" when unknown.
static func for_hit(event: Dictionary, attacker_style: String, config: GameConfig) -> Dictionary:
	var kind := int(event.get("attack_kind", -1))
	if kind == AttackSet.Kind.HAMMER:
		return {"name": "squeak", "pitch": 1.0, "volume_db": 0.0}  # the toy hammer always squeaks
	var k := float(event["knockback"])
	var heavy := k >= config.spark_large_threshold
	var pitch := clampf(BASE_PITCH - k * config.sfx_pitch_per_knockback, MIN_PITCH, MAX_PITCH)
	if ITEMS.has(kind):
		return {"name": String(ITEMS[kind]), "pitch": pitch, "volume_db": 0.0}
	var family: Array = FAMILIES.get(attacker_style, FISTS)
	return {"name": String(family[1] if heavy else family[0]), "pitch": pitch,
			"volume_db": 0.0 if heavy else LIGHT_VOLUME_DB}
