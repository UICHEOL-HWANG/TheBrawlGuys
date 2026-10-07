class_name BurstLooks
extends RefCounted
## MagicBurst looks per combat moment (combat-motion B): keys core / halo / ring (Color),
## spark (Array of Color), size (flash radius, m), flash_alpha / halo_alpha (peak opacity),
## reach (ring radius, m; 0 = none), ring_y (ring height from the burst centre), sparks (count),
## spark_speed (m/s), spark_size (m), rise (m), life (s).

## Height of a fighter's chest above its feet (aura and grip centres).
const CHEST := 0.9


## The flash where a projectile leaves the hand.
static func muzzle(kind: int) -> Dictionary:
	if kind == Projectile.Kind.FIREBALL:
		return _fire(0.45, 1.2, 8, 0.25)
	var heavy := kind == Projectile.Kind.HEAVY_BOLT
	return {"core": DS.WHITE, "halo": DS.CLANG, "ring": DS.BERRY if not heavy else DS.P4, "spark": [DS.CLANG, DS.WHITE],
			"size": 0.5 if heavy else 0.36, "reach": 0.95 if heavy else 0.65, "sparks": 8 if heavy else 6,
			"spark_speed": 4.0, "spark_size": 0.08, "life": 0.22 if heavy else 0.18}


## A bolt hitting someone or fizzling out at the end of its range.
static func impact(kind: int) -> Dictionary:
	var heavy := kind == Projectile.Kind.HEAVY_BOLT
	return {"core": DS.WHITE, "halo": DS.BERRY if not heavy else DS.P4, "ring": DS.CLANG, "spark": [DS.CLANG, DS.BERRY, DS.WHITE],
			"size": 0.7 if heavy else 0.5, "reach": 1.3 if heavy else 0.95, "sparks": 12 if heavy else 8,
			"spark_speed": 6.0, "spark_size": 0.1, "life": 0.32 if heavy else 0.26}


## The big fireball's blast, filling its hit radius.
static func explosion(config: GameConfig) -> Dictionary:
	var r := config.fireball_explode_radius
	return _fire(r * 0.45, r, 18, 0.6)


## The power-up burst around a fighter starting a special: a ring at the feet and rising sparks.
static func aura(color: Color) -> Dictionary:
	return {"core": DS.WHITE, "halo": color, "ring": color, "spark": [color, DS.GLOW, DS.WHITE],
			"size": 0.5, "flash_alpha": 0.45, "halo_alpha": 0.25, "reach": 1.8, "ring_y": -CHEST + 0.06,
			"sparks": 14, "spark_speed": 3.0, "spark_size": 0.12, "rise": 1.4, "life": 0.42}


## The ground slam's shockwave: a cream ring along the ground out to the slam radius, dirt flung up.
static func shockwave(radius: float, color: Color) -> Dictionary:
	return {"core": DS.GLOW, "halo": color, "ring": DS.IMPACT_CORE, "spark": [DS.DIRT, DS.STONE_SHADE, DS.GRASS_MID],
			"size": 0.35, "flash_alpha": 0.6, "halo_alpha": 0.25, "reach": radius, "ring_y": 0.0, "sparks": 16,
			"spark_speed": 7.0, "spark_size": 0.14, "rise": 0.9, "life": 0.5}


## A throw leaving the holder's hands: a quick whoosh ring in the thrower's color.
static func throw_whoosh(color: Color) -> Dictionary:
	return {"core": DS.WHITE, "halo": color, "ring": color, "spark": [color, DS.WHITE],
			"size": 0.35, "reach": 1.3, "sparks": 6, "spark_speed": 5.0, "spark_size": 0.08, "life": 0.28}


static func _fire(size: float, reach: float, sparks: int, life: float) -> Dictionary:
	return {"core": DS.GLOW, "halo": DS.FIRE, "halo_alpha": 0.75, "ring": DS.DANGER,
			"spark": [DS.PETAL_YELLOW, DS.FIRE, DS.DANGER], "size": size, "reach": reach, "sparks": sparks,
			"spark_speed": 2.0 + reach * 2.5, "spark_size": 0.06 + reach * 0.12, "rise": reach * 0.3, "life": life}
