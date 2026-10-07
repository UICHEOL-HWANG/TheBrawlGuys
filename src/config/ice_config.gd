class_name IceConfig
extends Resource
## Frozen pond ice (PRD §6.1): how slippery an ArenaData.slippery floor is (GroundGrip). The base
## of the GameConfig chain (ItemExtrasConfig extends this), so every value is a GameConfig value
## with a debug panel slider. "Ice" is a sim group: it enters the fingerprint. Arenas whose floor
## is not slippery never read these values, so their runs stay bit-identical.

@export_group("Ice")
## Walking on ice speeds up and slows down toward the stick at this rate (m/s^2) instead of
## snapping to it: about 0.4 s to full run speed and a ~1.3 m skid to a stop at 14.
@export_range(1.0, 80.0, 0.5) var ice_ground_acceleration: float = 14.0
## Share of a slide's speed kept per tick on ice (hitstun, lying, guard push); grippy floors use
## hitstun_ground_friction. 0.95 slides about three times as far as the 0.85 default.
@export_range(0.5, 1.0, 0.005) var ice_slide_friction: float = 0.95
