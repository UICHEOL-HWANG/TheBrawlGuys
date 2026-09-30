class_name ArenaDressings
extends RefCounted
## Registry of per-arena set dressings: maps an ArenaCatalog id to its dressing file.


static func create(arena_id: String) -> ArenaDressing:
	match arena_id:
		"lakeside_camp":
			return LakesideCampView.new()
		"log_bridge":
			return LogBridgeView.new()
		"mushroom_forest":
			return MushroomForestView.new()
		"foggy_forest":
			return FoggyForestView.new()
	return ClassicArenaView.new()
