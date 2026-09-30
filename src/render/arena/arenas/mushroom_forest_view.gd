class_name MushroomForestView
extends ArenaDressing
## Mushroom forest (PRD-ARENA-03): giant glowing mushrooms (pink and berry, DS-THM-02) mixed with
## golden bushes around the clearing. The bounce mushrooms on the floor are MushroomPadView.

const MUSHROOM_EVERY := 2
const CAP_COLORS: Array[Color] = [DS.PETAL_PINK, DS.BERRY]


func make_prop(rng: RandomNumberGenerator, i: int) -> Dictionary:
	if i % MUSHROOM_EVERY != 0:
		return super(rng, i)
	var size := rng.randf_range(0.9, 1.5)
	var m := TallMushroom.new()
	var height := m.setup(CAP_COLORS[(i / MUSHROOM_EVERY) % CAP_COLORS.size()], size, rng.randi())
	return {"node": m, "radius": TallMushroom.CAP_RADIUS * size, "height": height}
