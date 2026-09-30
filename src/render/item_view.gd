class_name ItemView
extends Node3D
## One loose item (design.md DS-VIS-05): a planked crate while falling from the sky, with a soft
## round shadow on the ground below that grows as it drops (the race starts here), then the
## item's own procedural model (ItemModels, Phase 4 T8): a bat cracked by its swings, a bomb whose
## spark burns down the fuse, a rock that tumbles in flight. Reads item view values only.

const SHADOW_RADIUS := 0.6
const SHADOW_HEIGHT := 0.01
const SHADOW_LIFT := 0.02
const SHADOW_MIN_SCALE := 0.4

var _config: GameConfig
var _boxed: bool = true
var _crate: CrateModel
var _model: ItemModel
var _shadow: MeshInstance3D


static func shadow_scale(height: float, drop_height: float) -> float:
	var t := 1.0 - clampf(height / maxf(drop_height, 0.01), 0.0, 1.0)
	return lerpf(SHADOW_MIN_SCALE, 1.0, t)


func setup(kind: int, config: GameConfig, boxed: bool = true) -> void:
	_config = config
	_boxed = boxed
	_crate = ItemModels.crate()
	add_child(_crate)
	_model = ItemModels.create(kind)
	add_child(_model)
	_model.transform = _model.ground_transform()
	if _model is BombModel:
		(_model as BombModel).fuse_total = SimTime.to_ticks(config.bomb_fuse_time)
	elif _model is BatModel:
		(_model as BatModel).max_uses = config.bat_uses
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_RADIUS
	disc.bottom_radius = SHADOW_RADIUS
	disc.height = SHADOW_HEIGHT
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = ToonMaterials.translucent(DS.GROUND_SHADOW)
	add_child(_shadow)


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	var to: Vector3 = curr["pos"]
	position = (prev["pos"] as Vector3).lerp(to, alpha) if not prev.is_empty() else to
	var falling := int(curr["state"]) == Item.State.FALLING
	var show_box := falling and _boxed
	_crate.visible = show_box
	_model.visible = not show_box
	_shadow.visible = falling
	if falling:
		_shadow.position.y = SHADOW_LIFT - position.y
		var s := shadow_scale(position.y, _config.item_drop_height)
		_shadow.scale = Vector3(s, 1.0, s)
	_model.show_state(curr, tick)


func box_visible() -> bool:
	return _crate.visible


func shape_visible() -> bool:
	return _model.visible


func shadow_visible() -> bool:
	return _shadow.visible


func model() -> ItemModel:
	return _model
