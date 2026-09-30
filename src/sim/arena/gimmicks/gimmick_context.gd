class_name GimmickContext
extends RefCounted
## What a gimmick may read during one tick (Gimmick.step).

var fighters: Array[Fighter]
var arena: ArenaData
var config: GameConfig
## World tick being simulated (0-based, before the World increments tick_count).
var tick: int
## Events already produced earlier in this tick (hits for breakable platforms).
var events: Array[Dictionary]


func _init(p_fighters: Array[Fighter], p_arena: ArenaData, p_config: GameConfig, p_tick: int,
		p_events: Array[Dictionary]) -> void:
	fighters = p_fighters
	arena = p_arena
	config = p_config
	tick = p_tick
	events = p_events
