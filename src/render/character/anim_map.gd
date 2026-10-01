class_name AnimMap
extends RefCounted
## Sim fighter view -> animation state (design.md GD-ANIM-01): a pure, read-only mapping. The
## animation never changes sim timing; attack clips are stretched to the sim length (Task 6).
## A special (Phase 5) plays its character's own motion, picked by the view's "special" id.

enum Anim {
	IDLE, RUN, JUMP, FALL, LIGHT, HEAVY, CHARGE, BAT, GRAB, HOLD, HELD, THROW, HIT, LAUNCHED, GUARD, KO,
	SLAM, RUSH, SPIN, CAST, LIE, GETUP, ROLL,
}

const TIMED: Array[int] = [Anim.LIGHT, Anim.HEAVY, Anim.BAT, Anim.GRAB]
const SPECIAL_ANIMS := {
	SpecialCatalog.GROUND_SLAM: Anim.SLAM, SpecialCatalog.DASH_RUSH: Anim.RUSH,
	SpecialCatalog.SPIN_SLASH: Anim.SPIN, SpecialCatalog.BIG_FIREBALL: Anim.CAST,
}


static func anim_for(view: Dictionary) -> int:
	var on_ground := bool(view["on_ground"])
	match int(view["state"]):
		Fighter.State.MOVE:
			return Anim.RUN
		Fighter.State.AIR:
			return Anim.JUMP
		Fighter.State.ATTACK:
			return _attack_anim(int(view["attack_kind"]))
		Fighter.State.CHARGE:
			return Anim.CHARGE
		Fighter.State.HITSTUN:
			return Anim.HIT if on_ground else Anim.LAUNCHED
		Fighter.State.GUARD:
			return Anim.GUARD
		Fighter.State.HOLDING:
			return Anim.HOLD
		Fighter.State.HELD:
			return Anim.HELD
		Fighter.State.KO:
			return Anim.KO
		Fighter.State.SPECIAL:
			return int(SPECIAL_ANIMS.get(String(view.get("special", "")), Anim.HEAVY))
		Fighter.State.DODGE:
			return Anim.RUN if on_ground else Anim.JUMP  # a roll / air dodge (combat-depth A)
		Fighter.State.KNOCKDOWN:
			return Anim.LIE
		Fighter.State.GETUP:
			return _getup_anim(String(view.get("getup", "")))
	return Anim.IDLE


## Getup kinds (combat-depth C): rolls roll, the getup attack swings like a heavy, the rest stand.
static func _getup_anim(kind: String) -> int:
	match kind:
		"roll", "tech_roll":
			return Anim.ROLL
		"attack":
			return Anim.HEAVY
	return Anim.GETUP


static func anim_name(anim: int) -> String:
	return Anim.keys()[anim]


static func is_timed(anim: int) -> bool:
	return TIMED.has(anim)


static func _attack_anim(kind: int) -> int:
	match kind:
		AttackSet.Kind.HEAVY:
			return Anim.HEAVY
		AttackSet.Kind.BAT:
			return Anim.BAT
		AttackSet.Kind.GRAB:
			return Anim.GRAB
		AttackSet.Kind.THROW:
			return Anim.THROW
	return Anim.LIGHT
