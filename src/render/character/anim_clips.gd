class_name AnimClips
extends RefCounted
## Candidate clip names per animation state (context F4). resolve() picks the first candidate the
## model really ships, so small naming differences between packs never break the animator.
## Names verified against assets/characters/kaykit/animations.txt (all four characters share 75 clips).

const CANDIDATES := {
	AnimMap.Anim.IDLE: ["Idle", "Unarmed_Idle", "2H_Melee_Idle"],
	AnimMap.Anim.RUN: ["Running_A", "Running_B", "Running_Strafe_Right", "Walking_A"],
	AnimMap.Anim.JUMP: ["Jump_Idle", "Jump_Full_Short", "Jump_Start"],
	AnimMap.Anim.FALL: ["Jump_Idle", "Jump_Full_Long"],
	AnimMap.Anim.LIGHT: ["Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B", "1H_Melee_Attack_Stab"],
	AnimMap.Anim.HEAVY: ["Unarmed_Melee_Attack_Kick", "2H_Melee_Attack_Slice", "1H_Melee_Attack_Chop"],
	AnimMap.Anim.CHARGE: ["Spellcasting", "2H_Melee_Idle", "Block"],
	AnimMap.Anim.BAT: ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Chop"],
	AnimMap.Anim.GRAB: ["Interact", "PickUp", "Unarmed_Melee_Attack_Punch_A"],
	AnimMap.Anim.HOLD: ["Unarmed_Pose", "Block", "Idle"],
	AnimMap.Anim.HELD: ["Hit_B", "Hit_A"],
	AnimMap.Anim.THROW: ["Throw", "1H_Ranged_Shoot"],
	AnimMap.Anim.HIT: ["Hit_A", "Hit_B"],
	AnimMap.Anim.LAUNCHED: ["Hit_B", "Jump_Idle", "Hit_A"],
	AnimMap.Anim.GUARD: ["Blocking", "Block", "Unarmed_Pose"],
	AnimMap.Anim.KO: ["Death_A", "Death_B", "Lie_Idle"],
}
const LOOPING: Array[int] = [
	AnimMap.Anim.IDLE, AnimMap.Anim.RUN, AnimMap.Anim.FALL, AnimMap.Anim.CHARGE, AnimMap.Anim.HOLD,
	AnimMap.Anim.HELD, AnimMap.Anim.GUARD, AnimMap.Anim.LAUNCHED, AnimMap.Anim.JUMP,
]


static func resolve(available: PackedStringArray) -> Dictionary:
	var idle := first_present(CANDIDATES[AnimMap.Anim.IDLE], available)
	if idle.is_empty():
		idle = available[0] if available.size() > 0 else ""
	var out := {}
	for a: int in AnimMap.Anim.values():
		var clip := first_present(CANDIDATES[a], available)
		out[a] = clip if not clip.is_empty() else idle
	return out


static func first_present(candidates: Array, available: PackedStringArray) -> String:
	for c: String in candidates:
		if available.has(c):
			return c
	return ""


static func loops(anim: int) -> bool:
	return LOOPING.has(anim)
