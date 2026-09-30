class_name FoggyForestTheme
extends RefCounted
## Foggy forest (DS-THM-02): cold early-morning light, a gray-green floor and a light sky-colored
## mist that thickens while the fog gimmick is active (FogView, EnvironmentRig.set_fog_boost).

const MORNING_SUN_DEG := Vector3(-38.0, -40.0, 0.0)
const BASE_FOG_DENSITY := 0.012


static func make() -> ArenaTheme:
	var t := ArenaTheme.new()
	t.floor_top = DS.GRASS_MIST
	t.floor_lip = DS.STONE_CREAM
	t.outer_ground = DS.GRASS_MIST_DEEP
	t.bush = DS.GRASS_MIST_DEEP
	t.canopy = DS.CANOPY_MIST
	t.sky = DS.FOG_MIST
	t.ambient = DS.SKY
	t.sun_color = DS.SUN_COOL
	t.sun_rotation_deg = MORNING_SUN_DEG
	t.sun_scale = 0.9
	t.ambient_scale = 1.1
	t.fog_color = DS.FOG_MIST
	t.fog_density = BASE_FOG_DENSITY
	return t
