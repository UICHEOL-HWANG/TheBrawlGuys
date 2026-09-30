extends "res://src/main/main.gd"
## Phase 2 evidence scene (PHASES Phase 2 "상자가 떨어지면 서로 먼저 가려고 한다"): both fighters
## are step-2 bots standing on opposite sides; a bat box drops between them at DROP_TICK, so the
## video shows both racing for it.

const DROP_TICK := 10
const START_X := 6.0
const DROP_OFFSET := Vector3(0, 0, 0.5)

var _p1_bot: BotController


func _start_match() -> void:
	super._start_match()
	_p1_bot = BotController.new(LOCAL_PLAYER, _config)
	var w := get_world()
	w.fighters[LOCAL_PLAYER].pos = Vector3(-START_X, 0, 0)
	w.fighters[BOT_PLAYER].pos = Vector3(START_X, 0, 0)


func _gather_inputs() -> Array[InputFrame]:
	var w := get_world()
	if w.tick_count == DROP_TICK:
		w.items.add(Item.Kind.BAT, DROP_OFFSET + Vector3.UP * _config.item_drop_height, Item.State.FALLING, _config)
	var inputs: Array[InputFrame] = [_p1_bots[0].sample(_curr_state), _bots[0].sample(_curr_state)]
	return inputs
