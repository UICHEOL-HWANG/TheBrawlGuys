class_name ArenaPreview
extends SubViewportContainer
## A static, actual match arena render. Only redraws on selection/resize.

var _viewport: SubViewport
var _arena: ArenaView
var _camera: Camera3D
var _env: EnvironmentRig
var _config: GameConfig
var _id := ""


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DS.CARD_WIDTH, DS.CARD_THUMB_HEIGHT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	resized.connect(_redraw)


func setup(config: GameConfig) -> void:
	_config = config
	_env = EnvironmentRig.new()
	_viewport.add_child(_env)
	_env.setup()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_viewport.add_child(_camera)


func show_arena(id: String) -> void:
	if id == _id or _config == null or not ArenaCatalog.ids().has(id):
		return
	if not is_inside_tree():
		ready.connect(show_arena.bind(id), CONNECT_ONE_SHOT)
		return
	_id = id
	if _arena != null:
		_viewport.remove_child(_arena)
		_arena.queue_free()
	_arena = ArenaView.new()
	_viewport.add_child(_arena)
	_arena.setup(_config, id)
	var decor := DecorView.new()
	_arena.add_child(decor)
	decor.setup(_config, 7, _arena.arena(), _arena.theme())
	_env.apply_theme(_arena.theme())
	var radius := _arena.arena().view_radius()
	_camera.size = radius * 2.9
	_camera.look_at_from_position(Vector3(radius, radius * 1.65, radius * 1.3), Vector3.ZERO)
	_redraw()


func _redraw() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_preview() -> void:
	setup(GameConfig.new())
	show_arena("lakeside_camp")
