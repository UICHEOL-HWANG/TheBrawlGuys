class_name LightFeathers
extends Node3D
## A fighter made light by the feather glove (design.md DS-VIS-04, PRD-ITEM-06): a few glow-yellow
## feathers slowly circling the body and bobbing, so "this one flies far right now" reads at a
## glance without covering the character. Origin at the fighter's feet.

const FEATHER_COUNT := 4
const FEATHER := Vector3(0.05, 0.16, 0.09)
const ORBIT_HZ := 0.35
const BOB := 0.12
const ORBIT_RADIUS := 1.3
const HEIGHT := 0.75

var _config: GameConfig
var _feathers: Array[MeshInstance3D] = []
var _time: float = 0.0


func setup(config: GameConfig) -> void:
	_config = config
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	for i: int in FEATHER_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = ToonMaterials.toon(DS.GLOW, 0.6)
		mi.scale = FEATHER
		add_child(mi)
		_feathers.append(mi)
	visible = false


func set_light(on: bool) -> void:
	visible = on


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var r := _config.fighter_radius * ORBIT_RADIUS
	for i: int in _feathers.size():
		var a := TAU * (_time * ORBIT_HZ + float(i) / _feathers.size())
		var y := _config.fighter_height * HEIGHT + sin(a * 2.0) * BOB
		_feathers[i].position = Vector3(cos(a) * r, y, sin(a) * r)
		_feathers[i].rotation = Vector3(0.0, -a, 0.6)
