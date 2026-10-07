class_name ArenaDressings
extends RefCounted
## Registry of per-arena set dressings: maps an ArenaCatalog id to its dressing file. Ids without
## their own dressing (the classic circle, unknown ids) get the classic meadow.


static func create(arena_id: String) -> ArenaDressing:
	return dressing_script(arena_id).new() as ArenaDressing


## True when the arena is dressed as the classic meadow, whose lake at +x makes ring-outs over
## it splash (ClassicArenaView.has_decor_lake, DecorView.is_water_ringout).
static func has_decor_lake(arena_id: String) -> bool:
	return dressing_script(arena_id) == ClassicArenaView


static func dressing_script(arena_id: String) -> GDScript:
	match arena_id:
		"lakeside_camp":
			return LakesideCampView
		"log_bridge":
			return LogBridgeView
		"mushroom_forest":
			return MushroomForestView
		"foggy_forest":
			return FoggyForestView
		"frozen_pond":
			return FrozenPondView
	return ClassicArenaView
