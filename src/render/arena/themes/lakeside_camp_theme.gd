class_name LakesideCampTheme
extends RefCounted
## Lakeside camp (DS-THM-02): reference A as it is, a warm midday. The campfire's own glow comes
## from CampfireView; the lake is drawn from the arena's ring-out zone.


static func make() -> ArenaTheme:
	var t := ArenaTheme.new()
	t.sun_scale = 1.05
	return t
