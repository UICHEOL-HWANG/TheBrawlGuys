class_name FogCycle
extends Gimmick
## Periodic fog (PRD-ARENA-04): on from fog_first_time for fog_duration, again every fog_period.
## A pure function of the tick; the sim only toggles the state and reports fog_start / fog_end.
## The render layer hides the far arena and keeps fighter silhouettes visible (DS-VIS-03).

var active: bool = false


static func make() -> FogCycle:
	return FogCycle.new()


func kind() -> String:
	return "fog"


static func active_at(tick: int, config: GameConfig) -> bool:
	var first := SimTime.to_ticks(config.fog_first_time)
	if tick < first:
		return false
	var period := maxi(SimTime.to_ticks(config.fog_period), 1)
	return (tick - first) % period < SimTime.to_ticks(config.fog_duration)


func step(ctx: GimmickContext) -> Array[Dictionary]:
	var want := active_at(ctx.tick, ctx.config)
	if want == active:
		return []
	active = want
	if active:
		return [{"type": "fog_start", "id": id, "ticks": SimTime.to_ticks(ctx.config.fog_duration)}]
	return [{"type": "fog_end", "id": id}]


func copy() -> Gimmick:
	var g := FogCycle.new()
	g.active = active
	return copy_base_into(g)


func to_data() -> Dictionary:
	return {"active": active}


func load_data(d: Dictionary) -> bool:
	if typeof(d.get("active")) != TYPE_BOOL:
		return false
	active = d["active"]
	return true


func view_state() -> Dictionary:
	return {"active": active}
