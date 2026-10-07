class_name ProjectileLook
extends RefCounted
## How each projectile kind looks (combat-motion B1). Bolts are magic orbs (white-hot core, cyan
## glow, violet halo) with a short fading trail; the heavy bolt is bigger, violet and pulses; the big
## fireball is a flickering flame sphere (pale-yellow core, orange body, red rim) shedding embers.
## Sizes are multiples of the sim collision radius, so retuned projectiles keep their look.

## Visual radius as a multiple of the sim radius (the halo reaches a bit past the hitbox).
const HALO_MUL := {Projectile.Kind.BOLT: 1.25, Projectile.Kind.HEAVY_BOLT: 1.3, Projectile.Kind.FIREBALL: 1.15}
## A bolt never draws smaller than this (the match camera is far away).
const MIN_RADIUS := 0.32
## Body and core as fractions of the halo.
const BODY_RATIO := 0.72
const CORE_RATIO := 0.42
const HALO_ALPHA := 0.5
const BODY_ALPHA := 0.85


static func colors(kind: int) -> Dictionary:
	match kind:
		Projectile.Kind.FIREBALL:
			return {"core": DS.GLOW, "body": DS.FIRE, "halo": DS.DANGER, "trail": [DS.FIRE, DS.DANGER, DS.PETAL_YELLOW]}
		Projectile.Kind.HEAVY_BOLT:
			return {"core": DS.WHITE, "body": DS.P4, "halo": DS.CLANG, "trail": [DS.P4, DS.CLANG]}
	return {"core": DS.WHITE, "body": DS.CLANG, "halo": DS.P4, "trail": [DS.CLANG, DS.P4]}


## Outer (halo) radius drawn for a projectile of sim `radius`.
static func visual_radius(kind: int, radius: float) -> float:
	return maxf(radius * float(HALO_MUL.get(kind, 1.2)), MIN_RADIUS)


## Trail ghosts kept behind the head (frames of history).
static func trail_count(kind: int) -> int:
	return 10 if kind == Projectile.Kind.FIREBALL else 7


## Pulse (Hz, amount) of the whole orb: the heavy bolt throbs, the fireball breathes.
static func pulse(kind: int) -> Vector2:
	match kind:
		Projectile.Kind.HEAVY_BOLT:
			return Vector2(7.0, 0.16)
		Projectile.Kind.FIREBALL:
			return Vector2(3.0, 0.08)
	return Vector2(10.0, 0.06)


## Flame flicker amount of the core (fireball only).
static func flicker(kind: int) -> float:
	return 0.22 if kind == Projectile.Kind.FIREBALL else 0.0
