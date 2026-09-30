class_name GimmickRunner
extends RefCounted
## The gimmick step of World.tick (after combat and items, before ring-outs): burning ticks
## first, then every arena gimmick in id order. Deterministic: no RNG, only tick and state.


static func step(arena: ArenaData, fighters: Array[Fighter], config: GameConfig, tick: int,
		tick_events: Array[Dictionary]) -> Array[Dictionary]:
	var events := Burning.step(fighters, config)
	if arena.gimmicks.is_empty():
		return events
	var ctx := GimmickContext.new(fighters, arena, config, tick, tick_events)
	for g: Gimmick in arena.gimmicks:
		events.append_array(g.step(ctx))
	return events
