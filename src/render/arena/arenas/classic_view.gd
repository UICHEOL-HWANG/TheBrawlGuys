class_name ClassicArenaView
extends ArenaDressing
## The Phase 1-3 meadow: bushes and trees around the ring and the meadow lake at +x (ring-outs
## over it splash). No set pieces of its own.


func has_decor_lake() -> bool:
	return true


func prop_ground(p: Vector3) -> float:
	if DecorView.is_over_lake(p, _config.arena_radius, ZONE_MARGIN):
		return NAN
	return super(p)
