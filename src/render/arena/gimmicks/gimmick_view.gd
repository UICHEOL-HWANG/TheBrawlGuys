class_name GimmickView
extends Node3D
## Base of the arena gimmick views (design.md DS-VIS-04 hazard marking). A view is built from one
## gimmick's plain view (Gimmick.to_view: kind, id, pos, area, state), follows it every frame in
## sync() and reacts to this frame's sim events in on_event(). Drawing only: never writes the sim.

var gimmick_id: int = -1
var _config: GameConfig
var _theme: ArenaTheme
var _time: float = 0.0


func setup(view: Dictionary, theme: ArenaTheme, config: GameConfig) -> void:
	_config = config
	_theme = theme
	gimmick_id = int(view.get("id", -1))
	if view.has("pos"):
		position = view["pos"]
	_build(view)


## Latest gimmick view at a sim tick; delta drives idle motion.
func sync(view: Dictionary, _tick: int, delta: float) -> void:
	_time += delta
	_follow(view, delta)


func on_event(_e: Dictionary) -> void:
	pass


## Arena floor index this view draws itself (breakable planks), or -1.
func owned_floor() -> int:
	return -1


## 0..1 fog strength for arena-wide fog views.
func fog_amount() -> float:
	return 0.0


func _build(_view: Dictionary) -> void:
	pass


func _follow(_view: Dictionary, _delta: float) -> void:
	pass


func _area_radius(view: Dictionary) -> float:
	var area: Dictionary = view.get("area", {})
	return float(area.get("radius", 1.0))


func _mesh(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi
