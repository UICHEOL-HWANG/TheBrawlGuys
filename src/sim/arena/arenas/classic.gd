class_name ClassicArena
extends RefCounted
## The Phase 1-3 arena: one round floor of GameConfig.arena_radius, spawns on a ring at half the
## radius, items anywhere on the floor, no gimmicks. follow_config keeps the debug slider live.


static func build(config: GameConfig) -> ArenaData:
	var a := ArenaData.new()
	a.id = ArenaCatalog.DEFAULT_ID
	a.theme_id = ArenaCatalog.DEFAULT_ID
	a.follow_config = true
	a.add_floor(ArenaShape.circle(Vector3.ZERO, config.arena_radius))
	a.item_area = ArenaShape.circle(Vector3.ZERO, config.arena_radius)
	a.spawn_radius = config.arena_radius * ArenaData.SPAWN_RADIUS_RATIO
	return a
