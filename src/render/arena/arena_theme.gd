class_name ArenaTheme
extends RefCounted
## One arena's 3D look (design.md DS-THM-02): floor, edge and meadow colors, decor palette, water,
## sky, sun and ambient light, bloom and base fog, all from DS tokens. Only the 3D environment
## changes per arena; the UI keeps the common tokens so the HUD reads the same everywhere.
## Defaults are the reference-A midday of the classic arena; each theme file overrides a few.

var id: String = ""
var floor_top: Color = DS.GRASS
var floor_lip: Color = DS.GRASS_SUN
var rim: Color = DS.DIRT
var outer_ground: Color = DS.GRASS_MID
var bush: Color = DS.GRASS_MID
var canopy: Color = DS.CANOPY
var water: Color = DS.WATER
var sky: Color = DS.SKY
var ambient: Color = DS.SKY
var sun_color: Color = DS.GLOW
var sun_rotation_deg: Vector3 = EnvironmentRig.SUN_ROTATION_DEG
## Multipliers on EnvironmentRig's per-renderer measured energies.
var sun_scale: float = 1.0
var ambient_scale: float = 1.0
var glow_scale: float = 1.0
## Always-on distance fog (0 = none); the fog gimmick adds to it while active.
var fog_color: Color = DS.FOG_MIST
var fog_density: float = 0.0
## Floors are ice (frozen pond): FloorMesh draws ice slabs and IcePatchView draws breakable patches.
var ice_floor: bool = false


## The theme for an ArenaData.theme_id (unknown ids fall back to classic).
static func for_id(theme_id: String) -> ArenaTheme:
	var t: ArenaTheme
	match theme_id:
		"lakeside_camp":
			t = LakesideCampTheme.make()
		"log_bridge":
			t = LogBridgeTheme.make()
		"mushroom_forest":
			t = MushroomForestTheme.make()
		"foggy_forest":
			t = FoggyForestTheme.make()
		"frozen_pond":
			t = FrozenPondTheme.make()
		_:
			t = ArenaTheme.new()
	t.id = theme_id
	return t
