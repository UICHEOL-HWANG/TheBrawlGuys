class_name LogBridgeArena
extends RefCounted
## Log bridge (PRD-ARENA-02): a long narrow bridge over water along x. A solid middle spine is
## flanked by eight side planks (BreakablePlatform) that break one by one on a staggered
## schedule and come back later, so the bridge keeps narrowing to the spine. Anything that
## drops below the water line anywhere rings out ("water").

const ID := "log_bridge"
const LENGTH := 24.0
const SPINE_WIDTH := 1.8
const PLANK_LENGTH := 6.0
const PLANK_WIDTH := 1.2
const PLANKS_PER_SIDE := 4
const WATER_LINE := -0.5
const WATER_SIZE := 100.0
## Break slot of each plank (-z side left to right, then +z side): alternates sides and ends.
const BREAK_ORDER: Array[int] = [0, 5, 2, 7, 4, 1, 6, 3]
const SPAWNS: Array[Vector3] = [Vector3(-7, 0, 0), Vector3(7, 0, 0), Vector3(-2.5, 0, 0), Vector3(2.5, 0, 0)]


static func build() -> ArenaData:
	var a := ArenaData.new()
	a.id = ID
	a.theme_id = ID
	a.add_floor(ArenaShape.box(Vector3.ZERO, Vector2(LENGTH, SPINE_WIDTH)))
	var plank := 0
	for side: float in [-1.0, 1.0]:
		var z := side * (SPINE_WIDTH + PLANK_WIDTH) * 0.5
		for k: int in PLANKS_PER_SIDE:
			var x := -LENGTH * 0.5 + PLANK_LENGTH * (k + 0.5)
			var shape := ArenaShape.box(Vector3(x, 0.0, z), Vector2(PLANK_LENGTH, PLANK_WIDTH))
			var i := a.add_floor(shape)
			a.add_gimmick(BreakablePlatform.make(i, shape.copy(), BREAK_ORDER[plank]))
			plank += 1
	var width := SPINE_WIDTH + PLANK_WIDTH * 2.0
	a.item_area = ArenaShape.box(Vector3.ZERO, Vector2(LENGTH, width))
	a.spawn_points.assign(SPAWNS)
	a.ringout_zones.append(ArenaShape.box(Vector3(0.0, WATER_LINE, 0.0), Vector2(WATER_SIZE, WATER_SIZE), 0.0, "water"))
	return a
