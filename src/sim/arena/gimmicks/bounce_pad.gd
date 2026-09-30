class_name BouncePad
extends Gimmick
## Big mushroom (PRD-ARENA-03): a fighter standing on the pad (just landed or walked on) is
## launched straight up at bounce_speed, keeping its horizontal speed. Runs after Motion so a
## landing never rests on the pad. Held and holding fighters are skipped (the hold moves them).

const STANDING_TOLERANCE := 0.05


static func make(p_area: ArenaShape) -> BouncePad:
	var g := BouncePad.new()
	g.area = p_area
	return g


func kind() -> String:
	return "bounce_pad"


func step(ctx: GimmickContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in ctx.fighters:
		if not f.is_alive() or not f.on_ground:
			continue
		if f.state == Fighter.State.HELD or f.state == Fighter.State.HOLDING:
			continue
		if absf(f.pos.y - area.center.y) > STANDING_TOLERANCE or not area.contains_xz(f.pos):
			continue
		_launch(f, ctx.config)
		events.append({"type": "bounce", "fighter": f.id, "pad": id, "pos": f.pos})
	return events


static func _launch(f: Fighter, config: GameConfig) -> void:
	f.vel.y = config.bounce_speed
	f.on_ground = false
	f.jumps_left = config.max_jumps - 1
	if f.state == Fighter.State.IDLE or f.state == Fighter.State.MOVE or f.state == Fighter.State.GUARD:
		f.set_state(Fighter.State.AIR)


func copy() -> Gimmick:
	return copy_base_into(BouncePad.new())
