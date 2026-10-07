class_name SwingClips
extends RefCounted
## Which KayKit clip each swing plays and where its beats sit, per style and attack kind
## (combat-motion A1). start: the cocked pose the swing begins from; contact: the strike frame;
## end: where the recovery hands back to idle (seconds into the clip). Contacts were measured
## with scripts/measure_contact.gd (the striking bone farthest in front of the hips).
## SwingTiming maps the sim's startup / active / recovery onto start -> contact -> end.
## POSES are clips held on one frame with a small sway (holding a fighter, being held).

const JAB := {"clip": "Unarmed_Melee_Attack_Punch_A", "start": 0.28, "contact": 0.5, "end": 0.95}
## Punch_B is a left-right pair: the hook is its left half, the cross its right half.
const HOOK := {"clip": "Unarmed_Melee_Attack_Punch_B", "start": 0.05, "contact": 0.32, "end": 0.42}
const CROSS := {"clip": "Unarmed_Melee_Attack_Punch_B", "start": 0.4, "contact": 0.5, "end": 1.05}
const KICK := {"clip": "Unarmed_Melee_Attack_Kick", "start": 0.05, "contact": 0.38, "end": 0.8}
const SLASH := {"clip": "1H_Melee_Attack_Slice_Diagonal", "start": 0.0, "contact": 0.3, "end": 0.65}
const SWEEP := {"clip": "1H_Melee_Attack_Slice_Horizontal", "start": 0.0, "contact": 0.2, "end": 0.6}
const THRUST := {"clip": "1H_Melee_Attack_Stab", "start": 0.2, "contact": 0.55, "end": 1.1}
const CLEAVE := {"clip": "2H_Melee_Attack_Chop", "start": 0.25, "contact": 0.82, "end": 1.3}
const BOLT := {"clip": "Spellcast_Shoot", "start": 0.0, "contact": 0.23, "end": 0.7}
## The charged bolt: the same thrust with a longer push (1H_Ranged_Shoot hid the orb behind the hat).
const BLAST := {"clip": "Spellcast_Shoot", "start": 0.0, "contact": 0.3, "end": 0.9}
## Both hands thrust forward: reads as a grab, not a punch.
const LUNGE := {"clip": "Dualwield_Melee_Attack_Stab", "start": 0.25, "contact": 0.62, "end": 1.0}
const SLAM := {"clip": "2H_Melee_Attack_Chop", "start": 0.15, "contact": 0.85, "end": 1.4}
const FIREBALL := {"clip": "Spellcast_Shoot", "start": 0.0, "contact": 0.25, "end": 0.85}
## The getup attack hits all around (a radial hit): a full-turn spin, strike mid-turn.
const GETUP_SWEEP := {"clip": "2H_Melee_Attack_Spinning", "start": 0.0, "contact": 0.3, "end": 0.66}
## The toss out of a hold (the sim throws in one tick; the release pose holds through hitstop).
const THROW := {"clip": "Throw", "start": 0.6, "contact": 0.77, "end": 1.25}
## Render ticks of the toss after the release: a short hold on the release, then the follow-through.
const THROW_ACTIVE_TICKS := 2
const THROW_RECOVERY_TICKS := 16

const K := AttackSet.Kind
## Shared by every style unless the style overrides it.
const BASE := {K.LIGHT_1: JAB, K.LIGHT_2: HOOK, K.LIGHT_3: CROSS, K.HEAVY: KICK, K.GRAB: LUNGE,
		K.BAT: SWEEP, K.HAMMER: CLEAVE, K.GLOVE: JAB}
const STYLES := {
	StyleCatalog.WEAPON: {K.LIGHT_1: SLASH, K.LIGHT_2: SWEEP, K.LIGHT_3: THRUST, K.HEAVY: CLEAVE},
	StyleCatalog.RANGED: {K.LIGHT_1: BOLT, K.LIGHT_2: BOLT, K.LIGHT_3: BOLT, K.HEAVY: BLAST},
}
const SPECIALS := {SpecialCatalog.GROUND_SLAM: SLAM, SpecialCatalog.BIG_FIREBALL: FIREBALL}
## anim -> {clip, at (s), sway (s, peak), hz}
const POSES := {
	AnimMap.Anim.HOLD: {"clip": "Dualwield_Melee_Attack_Stab", "at": 0.72, "sway": 0.04, "hz": 1.6},
	AnimMap.Anim.HELD: {"clip": "Hit_B", "at": 0.2, "sway": 0.12, "hz": 3.2},
}


## The swing for this style's attack kind (special: the character's special id), or {}.
static func pick(style: String, kind: int, special: String) -> Dictionary:
	if kind == K.SPECIAL:
		return SPECIALS.get(special, {})
	var own: Dictionary = STYLES.get(style, {})
	return own.get(kind, BASE.get(kind, {}))


static func all_plans() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for table: Dictionary in [BASE, SPECIALS] + STYLES.values():
		for plan: Dictionary in table.values():
			if not out.has(plan):
				out.append(plan)
	out.append(THROW)
	out.append(GETUP_SWEEP)
	return out


## The clip held for a posed state at time `t` (seconds), or -1.0 if anim is not posed.
static func pose_time(anim: int, t: float) -> float:
	if not POSES.has(anim):
		return -1.0
	var pose: Dictionary = POSES[anim]
	return float(pose["at"]) + float(pose["sway"]) * sin(t * TAU * float(pose["hz"]))
