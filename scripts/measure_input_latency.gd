extends SceneTree
## Frames from a jump key press to the local fighter leaving the ground, counting the frame that
## draws it (PRD-NFR-03: <= 3). Run windowed so frame timing matches real play:
##   godot --path . -s res://scripts/measure_input_latency.gd

const MAIN_SCENE := "res://src/main/main.tscn"
const WARMUP_FRAMES := 30
const GIVE_UP_FRAMES := 30
const LIFT := 0.01
const BUDGET := 3

var _main: Node
var _frame: int = 0
var _pressed_at: int = -1


func _init() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == WARMUP_FRAMES:
		Input.action_press("p1_jump")
		_pressed_at = _frame
		return
	if _pressed_at < 0:
		return
	if _frame == _pressed_at + 1:
		Input.action_release("p1_jump")
	var w: World = _main.call("get_world")
	if w.fighters[0].pos.y > LIFT:
		var frames := _frame - _pressed_at + 1
		print("measure_input_latency: %d frames (budget %d)" % [frames, BUDGET])
		quit(0 if frames <= BUDGET else 1)
	elif _frame - _pressed_at > GIVE_UP_FRAMES:
		push_error("measure_input_latency: fighter never left the ground")
		quit(1)
