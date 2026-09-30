class_name MushroomForestArena
extends RefCounted
## Mushroom forest (PRD-ARENA-03): a round clearing with three big mushrooms (BouncePad) near
## the edge that throw anyone stepping on them high into the air.

const ID := "mushroom_forest"
const RADIUS := 10.0
const PAD_RING := 7.3
const PAD_RADIUS := 1.0
## Pad angles in degrees, clear of the four ring spawns at 0/90/180/270.
const PAD_ANGLES: Array[float] = [45.0, 165.0, 285.0]


static func build() -> ArenaData:
	var a := ArenaData.new()
	a.id = ID
	a.theme_id = ID
	a.add_floor(ArenaShape.circle(Vector3.ZERO, RADIUS))
	a.item_area = ArenaShape.circle(Vector3.ZERO, RADIUS)
	a.spawn_radius = RADIUS * ArenaData.SPAWN_RADIUS_RATIO
	for deg: float in PAD_ANGLES:
		var angle := deg_to_rad(deg)
		var at := Vector3(cos(angle) * PAD_RING, 0.0, sin(angle) * PAD_RING)
		a.add_gimmick(BouncePad.make(ArenaShape.circle(at, PAD_RADIUS)))
	return a
