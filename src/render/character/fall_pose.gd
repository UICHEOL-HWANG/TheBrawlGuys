class_name FallPose
extends RefCounted
## Draws one fighter's fall off the arena (arena-ringout A2, OffstageFall): tips the model over
## its feet by the lean (a dive over the edge) and rolls it by the flail, and holds the drawn body
## on the meadow instead of sinking it into the ground (water ring-outs happen at the water line,
## above the meadow). Only the model's rotation is written: HitReaction owns its position and
## scale, the tumble spin turns the glb inside it. MatchStage calls follow() every frame.

var _lean: float = 0.0
var _time: float = 0.0
var _spawn_id: int = -1


func follow(view: FighterView, curr: Dictionary, delta: float) -> void:
	var model := view.model()
	if model == null or not view.visible:
		return
	var spawn := int(curr.get("spawn_id", _spawn_id))
	if spawn != _spawn_id:  # a respawn starts upright
		_spawn_id = spawn
		_lean = 0.0
	_lean = OffstageFall.lean(_lean, curr, delta)
	if int(curr.get("hitstop_ticks", 0)) <= 0:  # hitstop freezes the flail with the rest
		_time += delta
	if OffstageFall.falling(curr):
		view.position.y = maxf(view.position.y, DecorView.GROUND_Y)
	model.rotation = Vector3(_lean, 0.0, OffstageFall.flail(_lean, _time))


func lean() -> float:
	return _lean
