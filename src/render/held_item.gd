class_name HeldItem
extends Node3D
## The item a fighter carries (design.md DS-VIS-05, Phase 4 T8): the kind's procedural model at
## its hand offset (ItemModels.hold_transform), parented to the character's right hand slot so it
## follows the swing; without a character model it floats at a fixed spot beside the capsule.
## The model is rebuilt only when the carried kind changes.

const HELD_SCALE := 0.8

var _config: GameConfig
var _model: ItemModel = null
var _kind: int = Fighter.NONE


## hand: the hand slot to ride on (null = stay where the caller put this node); hand_scale: the
## slot's world scale, undone so the item keeps its size on a scaled character.
func setup(config: GameConfig, hand: Node3D = null, hand_scale: float = 1.0) -> void:
	_config = config
	scale = Vector3.ONE * HELD_SCALE / maxf(hand_scale, 0.0001)
	if hand != null:
		if get_parent() != null:
			get_parent().remove_child(self)
		hand.add_child(self)
		position = Vector3.ZERO
	visible = false


func show_item(kind: int, uses: int) -> void:
	visible = kind != Fighter.NONE
	if kind == Fighter.NONE:
		return
	if kind != _kind:
		_swap(kind)
	_model.show_state({"uses": uses, "state": Item.State.GROUND}, 0)


func model() -> ItemModel:
	return _model


func kind() -> int:
	return _kind


func _swap(kind: int) -> void:
	if _model != null:
		_model.queue_free()
	_model = ItemModels.create(kind)
	add_child(_model)
	_model.transform = _model.hold_transform()
	if _model is BatModel:
		(_model as BatModel).max_uses = _config.bat_uses
	_kind = kind
