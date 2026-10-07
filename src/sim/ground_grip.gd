class_name GroundGrip
extends RefCounted
## How the floor holds a grounded fighter (PRD §4.1, frozen pond ice). Grippy floors snap walking
## to the stick and slow slides by GameConfig.hitstun_ground_friction, exactly as before ice
## existed; a slippery arena (ArenaData.slippery) eases walking toward the stick at
## ice_ground_acceleration and keeps ice_slide_friction of a slide's speed per tick.


## Grounded walking velocity toward the stick target (x, z) in m/s.
static func walk(f: Fighter, target: Vector2, config: GameConfig, arena: ArenaData) -> void:
	if not arena.slippery:
		f.vel.x = target.x
		f.vel.z = target.y
		return
	var flat := Vector2(f.vel.x, f.vel.z).move_toward(target, config.ice_ground_acceleration * SimTime.TICK_DT)
	f.vel.x = flat.x
	f.vel.z = flat.y


## Share of horizontal slide speed kept per grounded tick.
static func friction(config: GameConfig, arena: ArenaData) -> float:
	return config.ice_slide_friction if arena.slippery else config.hitstun_ground_friction
