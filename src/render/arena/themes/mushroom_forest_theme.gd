class_name MushroomForestTheme
extends RefCounted
## Mushroom forest (DS-THM-02): late-afternoon golden light from a low sun, a desaturated floor,
## golden bloom; the mushrooms glow on their own (MushroomPadView, decor mushrooms).

const LOW_SUN_DEG := Vector3(-32.0, 60.0, 0.0)


static func make() -> ArenaTheme:
	var t := ArenaTheme.new()
	t.floor_top = DS.GRASS_DUSK
	t.floor_lip = DS.GRASS_GOLD
	t.outer_ground = DS.GRASS_DUSK
	t.bush = DS.GRASS_GOLD
	t.canopy = DS.CANOPY_GOLD
	t.sky = DS.SKY_GOLD
	t.ambient = DS.SKY_GOLD
	t.sun_color = DS.SUN_GOLD
	t.sun_rotation_deg = LOW_SUN_DEG
	t.glow_scale = 1.6
	return t
