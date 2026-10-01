extends "res://src/main/main.gd"
## Performance scene (PRD-NFR-01, Phase 3): a four-fighter match where every fighter, the local
## slot included, is a step-2 bot. Used by scripts/measure_fps.gd.

const PERF_PLAYERS := 4

var _local_bot: BotController


func _player_count() -> int:
	return PERF_PLAYERS


func _start_match() -> void:
	super._start_match()
	_local_bot = BotController.new(LOCAL_PLAYER, _config)


func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = [_local_bot.sample(_curr_state)]
	for slot: int in setup.bot_slots():
		inputs.append(_squad.sample(slot, _curr_state))
	return inputs
