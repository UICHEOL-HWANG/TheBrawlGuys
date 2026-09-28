class_name ArenaView
extends Node3D
## Round grass arena with a thick dirt edge (DS-VIS-04). Rebuilds when arena_radius changes.

const TOP_THICKNESS := 0.2
const RIM_HEIGHT := 0.8
## >1 flares the rim outward below the grass edge so DS-VIS-04's dirt band
## is not self-occluded by the top disc from the high default camera.
const RIM_TAPER := 1.08
const SEGMENTS := 64

var _config: GameConfig
var _top: MeshInstance3D
var _rim: MeshInstance3D
var _built_radius: float = -1.0


func setup(config: GameConfig) -> void:
	_config = config
	_top = MeshInstance3D.new()
	_rim = MeshInstance3D.new()
	add_child(_top)
	add_child(_rim)
	_config.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var r := _config.arena_radius
	if is_equal_approx(r, _built_radius):
		return
	_built_radius = r

	var top := CylinderMesh.new()
	top.top_radius = r
	top.bottom_radius = r
	top.height = TOP_THICKNESS
	top.radial_segments = SEGMENTS
	_top.mesh = top
	_top.material_override = ToonMaterials.toon(DS.GRASS)
	_top.position.y = -TOP_THICKNESS * 0.5

	var rim := CylinderMesh.new()
	rim.top_radius = r
	rim.bottom_radius = r * RIM_TAPER
	rim.height = RIM_HEIGHT
	rim.radial_segments = SEGMENTS
	_rim.mesh = rim
	_rim.material_override = ToonMaterials.toon(DS.DIRT)
	_rim.position.y = -TOP_THICKNESS - RIM_HEIGHT * 0.5
