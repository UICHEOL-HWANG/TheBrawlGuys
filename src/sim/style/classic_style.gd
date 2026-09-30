class_name ClassicStyle
extends RefCounted
## The Phase 1-4 fighter: the plain GameConfig attack table and movement. Used when no character
## is set, so earlier arenas, bots and replays keep their exact behaviour.

const ID := "classic"


static func moves(c: GameConfig) -> StyleData:
	return StyleData.make(ID, null, c.move_speed, c.jump_velocity, c.air_acceleration, 1.0)


## base is this tick's classic table (AttackSet.from_config), shared by every style.
static func attacks(_c: GameConfig, base: AttackSet) -> AttackSet:
	return base
