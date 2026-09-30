class_name LakesideCampArena
extends RefCounted
## Lakeside camp (PRD-ARENA-01): a round clearing whose +x side drops into a lake. Falling past
## the edge over the lake rings out at the water line (LAKE_CENTER.y) instead of kill_y, so
## that side has no recovery. A campfire on the far side burns whoever touches it.

const ID := "lakeside_camp"
const RADIUS := 10.0
const LAKE_CENTER := Vector3(17.0, -0.5, 0.0)  # y = water line
const LAKE_RADIUS := 8.0
const CAMPFIRE_CENTER := Vector3(-4.0, 0.0, -3.5)
const CAMPFIRE_RADIUS := 0.9


static func build() -> ArenaData:
	var a := ArenaData.new()
	a.id = ID
	a.theme_id = ID
	a.add_floor(ArenaShape.circle(Vector3.ZERO, RADIUS))
	a.item_area = ArenaShape.circle(Vector3.ZERO, RADIUS)
	a.spawn_radius = RADIUS * ArenaData.SPAWN_RADIUS_RATIO
	a.ringout_zones.append(ArenaShape.circle(LAKE_CENTER, LAKE_RADIUS, "lake"))
	a.add_gimmick(BurnZone.make(ArenaShape.circle(CAMPFIRE_CENTER, CAMPFIRE_RADIUS)))
	return a
