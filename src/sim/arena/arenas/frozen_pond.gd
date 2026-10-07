class_name FrozenPondArena
extends RefCounted
## Frozen pond (얼음 연못, PRD §6.1): a slippery ice disc over cold water. The solid ice is an outer
## ring plus a 3 x 3 grid of slabs inside it (the middle and the four corners); the four edge cells
## of the grid are thin ice patches (BreakablePlatform) and the only cover over their holes, so
## each one cracks on the log bridge schedule, opens a hole into the water and refreezes later.
## Anything below the water line anywhere rings out ("water"). The floor is slippery (GroundGrip).

const ID := "frozen_pond"
const ICE_RADIUS := 9.0
## Inner edge of the outer ice ring; the slab grid reaches a little past it so the two overlap.
const ICE_INNER := 5.5
const GRID_REACH := 5.75
## Half size of the middle slab, which is also the half width of each patch.
const CORE_HALF := 1.75
const PATCH_MID := (CORE_HALF + GRID_REACH) * 0.5
const PATCH_LENGTH := GRID_REACH - CORE_HALF
## East, west, north, south: consecutive breaks alternate sides.
const PATCH_CENTERS: Array[Vector3] = [Vector3(PATCH_MID, 0, 0), Vector3(-PATCH_MID, 0, 0),
		Vector3(0, 0, PATCH_MID), Vector3(0, 0, -PATCH_MID)]
const BREAK_ORDER: Array[int] = [0, 2, 1, 3]
const WATER_LINE := -0.5
const WATER_SIZE := 100.0
## Spawns on the diagonals, on the corner slabs where they meet the ring.
const SPAWN_DIAG := 4.6
const SPAWNS: Array[Vector3] = [Vector3(-SPAWN_DIAG, 0, -SPAWN_DIAG), Vector3(SPAWN_DIAG, 0, SPAWN_DIAG),
		Vector3(SPAWN_DIAG, 0, -SPAWN_DIAG), Vector3(-SPAWN_DIAG, 0, SPAWN_DIAG)]


static func build() -> ArenaData:
	var a := ArenaData.new()
	a.id = ID
	a.theme_id = ID
	a.slippery = true
	a.add_floor(ArenaShape.ring(Vector3.ZERO, ICE_RADIUS, ICE_INNER))
	a.add_floor(ArenaShape.box(Vector3.ZERO, Vector2.ONE * CORE_HALF * 2.0))
	var corner := PATCH_MID
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			a.add_floor(ArenaShape.box(Vector3(sx * corner, 0, sz * corner), Vector2.ONE * PATCH_LENGTH))
	for k: int in PATCH_CENTERS.size():
		var c := PATCH_CENTERS[k]
		var size := Vector2(PATCH_LENGTH, CORE_HALF * 2.0) if c.z == 0.0 else Vector2(CORE_HALF * 2.0, PATCH_LENGTH)
		var shape := ArenaShape.box(c, size)
		a.add_gimmick(BreakablePlatform.make(a.add_floor(shape), shape.copy(), BREAK_ORDER[k]))
	a.item_area = ArenaShape.circle(Vector3.ZERO, ICE_RADIUS)
	a.spawn_points.assign(SPAWNS)
	a.ringout_zones.append(ArenaShape.box(Vector3(0.0, WATER_LINE, 0.0), Vector2(WATER_SIZE, WATER_SIZE), 0.0, "water"))
	return a
