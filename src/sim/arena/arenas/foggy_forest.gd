class_name FoggyForestArena
extends RefCounted
## Foggy forest (PRD-ARENA-04): a round clearing where fog rolls in on a fixed cycle (FogCycle).
## The fog changes only what players see; the sim just reports it.

const ID := "foggy_forest"
const RADIUS := 10.0


static func build() -> ArenaData:
	var a := ArenaData.new()
	a.id = ID
	a.theme_id = ID
	a.add_floor(ArenaShape.circle(Vector3.ZERO, RADIUS))
	a.item_area = ArenaShape.circle(Vector3.ZERO, RADIUS)
	a.spawn_radius = RADIUS * ArenaData.SPAWN_RADIUS_RATIO
	a.add_gimmick(FogCycle.make())
	return a
