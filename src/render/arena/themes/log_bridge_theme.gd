class_name LogBridgeTheme
extends RefCounted
## Log bridge (DS-THM-02): bright day with a high sun (short shadows), bark logs over water and a
## pale sky.

const HIGH_SUN_DEG := Vector3(-72.0, 20.0, 0.0)


static func make() -> ArenaTheme:
	var t := ArenaTheme.new()
	t.floor_top = DS.BARK
	t.floor_lip = DS.DIRT
	t.rim = DS.BARK
	t.sky = DS.SKY_PALE
	t.ambient = DS.SKY_PALE
	t.sun_rotation_deg = HIGH_SUN_DEG
	t.sun_scale = 1.1
	return t
