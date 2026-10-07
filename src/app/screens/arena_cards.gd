class_name ArenaCards
extends RefCounted
## What the arena select screen shows per stage (PRD-UI-02, DS-CMP-08): the Korean name, a one-line
## caption, the gimmick icon kinds and the diorama data for ArenaThumb, read from the arena's own
## ArenaData (floors, ring-out zones, gimmicks) and its theme colors.

const NAMES := {
	"lakeside_camp": ["호숫가 캠프장", "호수 낭떠러지 · 모닥불"],
	"log_bridge": ["통나무 다리", "점점 부서지는 발판"],
	"mushroom_forest": ["버섯 숲", "밟으면 튀어 오르는 버섯"],
	"foggy_forest": ["안개 낀 숲", "주기적으로 안개가 껴요"],
	"frozen_pond": ["얼음 연못", "미끄러운 얼음 · 깨지는 얼음판"],
}
## Gimmick kind -> GimmickIcon kind.
const ICONS := {"burn_zone": "fire", "platform": "crack", "bounce_pad": "bounce", "fog": "fog"}
## The thumbnail shows a little beyond the floor so a lake beside it reads.
const EXTENT_MARGIN := 1.3


## One entry per selectable stage, in ArenaCatalog order: {id, title, caption, icons, diorama}.
static func entries(config: GameConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ArenaCatalog.stage_ids():
		out.append(entry(id, config))
	return out


static func entry(id: String, config: GameConfig) -> Dictionary:
	var arena := ArenaCatalog.build(id, config)
	var names: Array = NAMES.get(id, [id, ""])
	return {"id": id, "title": names[0], "caption": names[1], "icons": icons(arena),
		"diorama": diorama(arena, ArenaTheme.for_id(arena.theme_id))}


static func icons(arena: ArenaData) -> Array[String]:
	var out: Array[String] = []
	if not arena.ringout_zones.is_empty():
		out.append("water")
	for g: Gimmick in arena.gimmicks:
		var icon := String(ICONS.get(g.kind(), ""))
		if not icon.is_empty() and not out.has(icon):
			out.append(icon)
	return out


static func diorama(arena: ArenaData, theme: ArenaTheme) -> Dictionary:
	var floors: Array[Dictionary] = []
	for s: ArenaShape in arena.floors:
		floors.append(s.to_view())
	var zones: Array[Dictionary] = []
	for z: ArenaShape in arena.ringout_zones:
		zones.append(z.to_view())
	var gimmicks: Array[Dictionary] = []
	for g: Dictionary in arena.gimmick_views():
		var area: Dictionary = g.get("area", {})
		gimmicks.append({"kind": g["kind"], "pos": g.get("pos", Vector3.ZERO), "radius": area.get("radius", 1.0)})
	return {"extent": arena.view_radius() * EXTENT_MARGIN, "floors": floors, "zones": zones,
		"gimmicks": gimmicks, "ground": theme.outer_ground, "floor": theme.floor_top, "rim": theme.rim,
		"water": theme.water, "canopy": theme.canopy}
