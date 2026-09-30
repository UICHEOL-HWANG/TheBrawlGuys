class_name StyleCatalog
extends RefCounted
## Style id -> the style file that builds it (one style per file, PRD-ARCH-03).

const CLASSIC := ClassicStyle.ID
const BOXER := BoxerStyle.ID
const WEAPON := WeaponStyle.ID
const RANGED := RangedStyle.ID
const IDS: Array[String] = [CLASSIC, BOXER, WEAPON, RANGED]


## The whole style: movement numbers plus its attack table (reshaped from base, or from a fresh
## AttackSet.from_config when base is null).
static func build(id: String, c: GameConfig, base: AttackSet = null) -> StyleData:
	var s := moves(id, c)
	s.attacks = attacks(id, c, base if base != null else AttackSet.from_config(c))
	return s


## Movement numbers only (StyleData.attacks stays null): cheap enough for every tick.
static func moves(id: String, c: GameConfig) -> StyleData:
	match id:
		BOXER:
			return BoxerStyle.moves(c)
		WEAPON:
			return WeaponStyle.moves(c)
		RANGED:
			return RangedStyle.moves(c)
	return ClassicStyle.moves(c)


static func attacks(id: String, c: GameConfig, base: AttackSet) -> AttackSet:
	match id:
		BOXER:
			return BoxerStyle.attacks(c, base)
		WEAPON:
			return WeaponStyle.attacks(c, base)
		RANGED:
			return RangedStyle.attacks(c, base)
	return ClassicStyle.attacks(c, base)


## The style's knockback_taken without building its attack table (Combat.apply_hit).
static func knockback_taken(id: String, c: GameConfig) -> float:
	match id:
		BOXER:
			return c.boxer_knockback_taken
		WEAPON:
			return c.weapon_knockback_taken
		RANGED:
			return c.ranged_knockback_taken
	return 1.0


## How far the style's melee reaches relative to classic (bots scale their swing range by it).
static func reach_mul(id: String, c: GameConfig) -> float:
	match id:
		BOXER:
			return c.boxer_reach_mul
		WEAPON:
			return c.weapon_reach_mul
	return 1.0
