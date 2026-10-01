class_name DamageColor
extends RefCounted
## Damage % -> DamageCounter color along the DS damage ramp (design.md DS-TOK-01: 0/50/100/150+).

const STOPS := [0.0, 50.0, 100.0, 150.0]


## ramp: four colors at STOPS (the PlayerCard bar passes CardBar.DAMAGE_BAR_RAMP).
static func for_percent(p: float, ramp: Array = DS.DAMAGE_RAMP) -> Color:
	if p <= STOPS[0]:
		return ramp[0]
	for i: int in range(1, STOPS.size()):
		if p <= STOPS[i]:
			if p == STOPS[i]:
				return ramp[i]  # exact stop; lerp at t=1.0 drifts by a float ulp
			var t: float = (p - STOPS[i - 1]) / (STOPS[i] - STOPS[i - 1])
			return (ramp[i - 1] as Color).lerp(ramp[i], t)
	return ramp[ramp.size() - 1]
