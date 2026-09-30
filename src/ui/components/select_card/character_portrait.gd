class_name CharacterPortrait
extends SubViewportContainer
## Character thumbnail for a SelectCard (design.md DS-CMP-08 썸네일, Phase 5 T9): the character's
## KayKit model idling on a small grass stage under the game's sun and sky (EnvironmentRig), in
## its own 3D world. Only live cards (focused or picked) redraw every frame; the others keep
## their last frame (UPDATE_ONCE) so four portraits cost about one on the menu.

const CAMERA_FROM := Vector3(0.75, 1.2, 3.0)
const CAMERA_AT := Vector3(0.0, 0.8, 0.0)
## Short (compact) portraits frame the head and chest so the character stays readable.
const CLOSE_FROM := Vector3(0.5, 1.25, 2.2)
const CLOSE_AT := Vector3(0.0, 1.05, 0.0)
const CAMERA_FOV := 34.0
const STAGE_RADIUS := 0.9
const STAGE_HEIGHT := 0.12
## The model turns a little toward the camera (3/4 view).
const MODEL_YAW := 0.35
const IDLE_VIEW := {"state": Fighter.State.IDLE, "on_ground": true, "attack_kind": -1, "item_kind": -1,
		"charge_ticks": 0, "hitstop_ticks": 0}

## Set before setup: the head-and-chest framing for short portraits.
var close_up: bool = false
var _vp: SubViewport
var _cam: Camera3D = null
var _model: CharacterModel = null
var _animator: CharacterAnimator = null
var _gear: StyleGear = null
var _live: bool = false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DS.CARD_WIDTH - DS.S5 * 2, DS.CARD_THUMB_HEIGHT)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	resized.connect(_redraw)


## entry: a CharacterCatalog entry. Builds the stage once the portrait is in the tree.
func setup(entry: Dictionary, config: GameConfig) -> void:
	if is_inside_tree():
		_build(entry, config)
	else:
		ready.connect(_build.bind(entry, config), CONNECT_ONE_SHOT)


## Live portraits redraw only while visible (the select screen stays alive, hidden, under the
## arena screen and the match); still ones keep their last frame.
func set_live(on: bool) -> void:
	_live = on
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if on else SubViewport.UPDATE_ONCE


## Short cards (compact phones) frame the head and chest; call again when the layout flips.
func set_close_up(on: bool) -> void:
	close_up = on
	if _cam != null:
		_cam.look_at_from_position(CLOSE_FROM if on else CAMERA_FROM, CLOSE_AT if on else CAMERA_AT, Vector3.UP)
	_redraw()


func is_live() -> bool:
	return _live


func model() -> CharacterModel:
	return _model


func viewport() -> SubViewport:
	return _vp


func animator() -> CharacterAnimator:
	return _animator


## The worn style gear (null until the model is built).
func gear() -> StyleGear:
	return _gear


func _process(delta: float) -> void:
	if _live and _animator != null and is_visible_in_tree():
		_animator.apply(IDLE_VIEW, delta)


## A still portrait draws one more frame (after a resize the old one may be gone).
func _redraw() -> void:
	if not _live:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build(entry: Dictionary, config: GameConfig) -> void:
	var env := EnvironmentRig.new()
	_vp.add_child(env)
	env.setup()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = STAGE_RADIUS
	cylinder.bottom_radius = STAGE_RADIUS
	cylinder.height = STAGE_HEIGHT
	var stage := MeshInstance3D.new()
	stage.mesh = cylinder
	stage.material_override = ToonMaterials.toon(DS.GRASS)
	stage.position.y = -STAGE_HEIGHT * 0.5
	_vp.add_child(stage)
	_cam = Camera3D.new()
	_cam.fov = CAMERA_FOV
	_vp.add_child(_cam)
	_cam.current = true
	set_close_up(close_up)
	var model := CharacterModel.new()
	_vp.add_child(model)
	if not model.setup(entry, config):
		model.queue_free()
		return
	model.rotation.y = MODEL_YAW
	_model = model
	if model.animation_player() != null:
		_animator = CharacterAnimator.new()
		model.add_child(_animator)
		_animator.setup(model.animation_player(), config)
	_dress(model)


## The match look (StyleGear, T8): the character's style gear and style idle, posed at once so a
## still portrait shows the stance too.
func _dress(model: CharacterModel) -> void:
	var id := model.character_id()
	_gear = StyleGear.new(model, _animator)
	_gear.follow({"character": id, "style": CharacterData.style_of(id)})
	if _animator != null:
		_animator.apply(IDLE_VIEW, 0.0)
