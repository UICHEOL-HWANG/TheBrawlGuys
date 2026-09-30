class_name BurnZone
extends Gimmick
## Campfire (PRD-ARENA-01): a fighter whose feet are inside the area and at most REACH_HEIGHT
## above it catches fire (Burning). Stateless: the burn lives on the fighter.

const REACH_HEIGHT := 1.0


static func make(p_area: ArenaShape) -> BurnZone:
	var g := BurnZone.new()
	g.area = p_area
	return g


func kind() -> String:
	return "burn_zone"


func step(ctx: GimmickContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in ctx.fighters:
		var height := f.pos.y - area.center.y
		if height < -REACH_HEIGHT or height > REACH_HEIGHT or not area.contains_xz(f.pos):
			continue
		var e := Burning.ignite(f, ctx.config)
		if not e.is_empty():
			events.append(e)
	return events


func copy() -> Gimmick:
	return copy_base_into(BurnZone.new())
