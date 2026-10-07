class_name FrozenPondTheme
extends RefCounted
## Frozen pond (DS-THM-02): a pale cold winter day. Snow-white ice with a pale-blue lip over
## pale-blue ice walls, deep blue water, a snowy bank with dark pines, a low cool sun.

const WINTER_SUN_DEG := Vector3(-34.0, 35.0, 0.0)
const BASE_FOG_DENSITY := 0.006


static func make() -> ArenaTheme:
	var t := ArenaTheme.new()
	t.ice_floor = true
	t.floor_top = DS.ICE
	t.floor_lip = DS.SKY
	t.rim = DS.ICE_DEEP
	t.outer_ground = DS.FOG_MIST
	t.bush = DS.STONE_CREAM
	t.canopy = DS.CANOPY_MIST
	t.water = DS.WATER_DEEP
	t.sky = DS.SKY_PALE
	t.ambient = DS.SKY
	t.sun_color = DS.SUN_COOL
	t.sun_rotation_deg = WINTER_SUN_DEG
	t.sun_scale = 0.85
	t.glow_scale = 0.6
	t.fog_color = DS.SKY_PALE
	t.fog_density = BASE_FOG_DENSITY
	return t
