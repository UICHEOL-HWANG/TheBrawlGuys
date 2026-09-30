class_name StyleData
extends RefCounted
## One fighting style's numbers for one tick (PRD §6.2, PRD-ARCH-03): its attack table and its
## movement overrides. Built from GameConfig by the style's own file (one style per file) through
## StyleCatalog, every tick, so debug-panel tuning applies at once. Plain values only.
## The special belongs to the character (CharacterData), not the style: two boxers differ there.

var id: String = ""
## null when only the movement numbers were built (StyleCatalog.moves).
var attacks: AttackSet
var move_speed: float = 0.0
var jump_velocity: float = 0.0
var air_acceleration: float = 0.0
## Multiplies the knockback a fighter of this style receives (weight; below 1 = heavier).
var knockback_taken: float = 1.0


static func make(p_id: String, p_attacks: AttackSet, speed: float, jump: float, air: float,
		taken: float) -> StyleData:
	var s := StyleData.new()
	s.id = p_id
	s.attacks = p_attacks
	s.move_speed = speed
	s.jump_velocity = jump
	s.air_acceleration = air
	s.knockback_taken = taken
	return s
