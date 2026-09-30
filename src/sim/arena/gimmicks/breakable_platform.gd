class_name BreakablePlatform
extends Gimmick
## Log bridge segment (PRD-ARENA-02): one arena floor that cracks, breaks away and comes back.
## Schedule: INTACT until platform_break_start_time + order * platform_break_interval, then
## CRACKING for platform_warn_time (render shows cracks, DS-VIS-04), then BROKEN (the floor is
## switched off, "platform_break") for platform_respawn_time, then INTACT again
## ("platform_restore") for platform_rebreak_time before the next crack. Hits taken by fighters
## standing on it and explosions over it count down platform_hits_to_break and crack it early.

enum State { INTACT, CRACKING, BROKEN }

## A hit target this close to the top counts as standing on the platform.
const STANDING_TOLERANCE := 0.1

var floor_index: int = 0
## Slot in the break schedule (0 breaks first).
var order: int = 0
var state: int = State.INTACT
## Ticks until the next state change.
var timer: int = 0
var hits: int = 0


static func make(p_floor_index: int, p_area: ArenaShape, p_order: int) -> BreakablePlatform:
	var g := BreakablePlatform.new()
	g.floor_index = p_floor_index
	g.area = p_area
	g.order = p_order
	return g


func kind() -> String:
	return "platform"


func start(config: GameConfig) -> void:
	state = State.INTACT
	hits = 0
	timer = SimTime.to_ticks(config.platform_break_start_time + order * config.platform_break_interval)


func step(ctx: GimmickContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	timer -= 1
	if timer <= 0:
		_advance(ctx, events)
	elif state == State.INTACT:
		hits += _hits_on_top(ctx)
		if hits >= ctx.config.platform_hits_to_break:
			_crack(ctx.config)
	return events


func _advance(ctx: GimmickContext, events: Array[Dictionary]) -> void:
	match state:
		State.INTACT:
			_crack(ctx.config)
		State.CRACKING:
			state = State.BROKEN
			timer = maxi(SimTime.to_ticks(ctx.config.platform_respawn_time), 1)
			ctx.arena.floor_active[floor_index] = false
			events.append({"type": "platform_break", "id": id, "pos": area.center})
		State.BROKEN:
			state = State.INTACT
			hits = 0
			timer = maxi(SimTime.to_ticks(ctx.config.platform_rebreak_time), 1)
			ctx.arena.floor_active[floor_index] = true
			events.append({"type": "platform_restore", "id": id, "pos": area.center})


func _crack(config: GameConfig) -> void:
	state = State.CRACKING
	timer = maxi(SimTime.to_ticks(config.platform_warn_time), 1)


func _hits_on_top(ctx: GimmickContext) -> int:
	var count := 0
	for e: Dictionary in ctx.events:
		var type: String = e["type"]
		if type == "hit" or type == "guard_hit":
			var target := Grab.find(ctx.fighters, int(e["target"]))
			# positions are pre-launch here (Combat runs after Motion), so height tells "standing on it"
			if target != null and absf(target.pos.y - area.center.y) <= STANDING_TOLERANCE \
					and area.contains_xz(target.pos):
				count += 1
		elif type == "explosion":
			var at: Vector3 = e["pos"]
			if area.contains_xz(at) and at.y - area.center.y <= ctx.config.bomb_radius:
				count += 1
	return count


func copy() -> Gimmick:
	var g := BreakablePlatform.new()
	g.floor_index = floor_index
	g.order = order
	g.state = state
	g.timer = timer
	g.hits = hits
	return copy_base_into(g)


func to_data() -> Dictionary:
	return {"state": state, "timer": timer, "hits": hits}


func load_data(d: Dictionary) -> bool:
	for key: String in ["state", "timer", "hits"]:
		if typeof(d.get(key)) != TYPE_INT:
			return false
	state = d["state"]
	timer = d["timer"]
	hits = d["hits"]
	return true


func view_state() -> Dictionary:
	return {
		"floor": floor_index, "state": state, "broken": state == State.BROKEN,
		"cracking": state == State.CRACKING, "ticks_left": timer, "hits": hits,
	}
