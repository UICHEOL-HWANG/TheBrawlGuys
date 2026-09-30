class_name FoggyForestView
extends ArenaDressing
## Foggy forest (PRD-ARENA-04): a ring of misty conifers with low gray-green bushes between them;
## the periodic fog itself is FogView.

const PINE_EVERY := 2


func make_prop(rng: RandomNumberGenerator, i: int) -> Dictionary:
	if i % PINE_EVERY != 0:
		return super(rng, i)
	var size := rng.randf_range(1.1, 1.6)
	var pine := PineTree.new()
	var height := pine.setup(_theme.canopy, size)
	return {"node": pine, "radius": PineTree.TIERS[0].x * size, "height": height}
