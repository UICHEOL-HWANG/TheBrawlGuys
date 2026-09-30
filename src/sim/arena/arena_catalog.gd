class_name ArenaCatalog
extends RefCounted
## Registry of arena definitions (PRD §6.1). Each arena lives in its own file under arenas/ and
## exposes build(config) -> ArenaData; this file only maps ids to them. build returns a fresh
## ArenaData every call, so every World owns its arena state.

const DEFAULT_ID := "classic"
## The four Phase 4 stages, in selection-screen order.
const STAGE_IDS: Array[String] = ["lakeside_camp", "log_bridge", "mushroom_forest", "foggy_forest"]


## The Phase 1-3 circle (radius = GameConfig.arena_radius, follows the debug slider).
static func default(config: GameConfig) -> ArenaData:
	return build(DEFAULT_ID, config)


static func ids() -> Array[String]:
	var out: Array[String] = [DEFAULT_ID]
	out.append_array(STAGE_IDS)
	return out


static func stage_ids() -> Array[String]:
	return STAGE_IDS.duplicate()


## A new arena for id, or null (with an error) for an unknown id.
static func build(id: String, config: GameConfig) -> ArenaData:
	var a: ArenaData = null
	match id:
		DEFAULT_ID:
			a = ClassicArena.build(config)
		"lakeside_camp":
			a = LakesideCampArena.build()
		"log_bridge":
			a = LogBridgeArena.build()
		"mushroom_forest":
			a = MushroomForestArena.build()
		"foggy_forest":
			a = FoggyForestArena.build()
		_:
			push_error("ArenaCatalog.build: unknown arena '%s'" % id)
			return null
	a.sync(config)
	return a
