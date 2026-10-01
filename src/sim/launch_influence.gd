class_name LaunchInfluence
extends RefCounted
## Directional influence (combat-depth C, PRD §4.2): a clean hit marks its target di_pending
## (Combat.apply_hit); on the target's first tick after the hitstop, Motion applies the move
## stick held then. The horizontal launch direction turns toward the stick's side by up to
## di_max_deg, in proportion to the stick's component perpendicular to the launch: a stick along
## (or against) the launch, or a neutral one, changes nothing. Speeds are kept.


## Motion.step, first advancing tick after a hit: bends the launch once, if still in hitstun.
static func apply(f: Fighter, input: InputFrame, config: GameConfig) -> void:
	if not f.di_pending:
		return
	f.di_pending = false
	if f.state == Fighter.State.HITSTUN:
		f.vel = rotate(f.vel, Vector2(input.move_x, input.move_z), config)


## vel with its horizontal part turned by di_max_deg times the stick's perpendicular share
## (positive toward the stick's side). stick is (move_x, move_z), clamped to length 1.
static func rotate(vel: Vector3, stick: Vector2, config: GameConfig) -> Vector3:
	var flat := Vector2(vel.x, vel.z)
	if flat.length_squared() <= 0.0 or stick.length_squared() <= 0.0:
		return vel
	var s := stick.limit_length(1.0)
	var perpendicular := flat.normalized().cross(s)  # sin of the angle from the launch to the stick
	if perpendicular == 0.0:
		return vel
	var turned := flat.rotated(deg_to_rad(config.di_max_deg) * perpendicular)
	return Vector3(turned.x, vel.y, turned.y)
