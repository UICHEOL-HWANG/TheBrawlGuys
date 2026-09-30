class_name BurnFlames
extends Node3D
## A burning fighter (design.md DS-VIS-04 지속 대미지 = fire 발광 + 불티, PRD-ARENA-01): little
## flame tongues licking up around the body and embers drifting off while the sim's burn lasts.
## Origin at the fighter's feet.

## Flame tongues: [x, y, z] at fighter radius / height 1.
const TONGUES: Array[Vector3] = [Vector3(0.7, 0.35, 0.3), Vector3(-0.6, 0.55, 0.4), Vector3(0.2, 0.8, -0.7),
		Vector3(-0.3, 0.25, -0.6)]
const TONGUE_RADIUS := 0.16
const TONGUE_HEIGHT := 0.42
const FLICKER_HZ := 6.0
const EMBER_COUNT := 6
const EMBER_RADIUS := 0.035
const EMBER_PERIOD := 0.9
const EMBER_RISE := 1.1

var _config: GameConfig
var _tongues: Array[MeshInstance3D] = []
var _embers: Array[MeshInstance3D] = []
var _time: float = 0.0


func setup(config: GameConfig) -> void:
	_config = config
	var flame := SphereMesh.new()
	flame.radius = TONGUE_RADIUS
	flame.height = TONGUE_HEIGHT
	for i: int in TONGUES.size():
		var t := TONGUES[i]
		var color := DS.FIRE if i % 2 == 0 else DS.PETAL_YELLOW
		var p := Vector3(t.x * config.fighter_radius, t.y * config.fighter_height, t.z * config.fighter_radius)
		_tongues.append(_add(flame, color, p))
	var ember := SphereMesh.new()
	ember.radius = EMBER_RADIUS
	ember.height = EMBER_RADIUS * 2.0
	var count := maxi(roundi(EMBER_COUNT * Quality.particle_scale(config)), 1)
	for i: int in count:
		_embers.append(_add(ember, DS.FIRE, Vector3.ZERO))
	visible = false


func set_burning(on: bool) -> void:
	visible = on


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i: int in _tongues.size():
		var f := 0.75 + 0.35 * absf(sin(_time * TAU * FLICKER_HZ * 0.5 + i * 1.3))
		_tongues[i].scale = Vector3(1.0 / f, f, 1.0 / f)
	for i: int in _embers.size():
		var t := fposmod(_time / EMBER_PERIOD + float(i) / _embers.size(), 1.0)
		var a := TAU * float(i) / _embers.size()
		var r := _config.fighter_radius * 0.8
		_embers[i].position = Vector3(cos(a) * r, _config.fighter_height * 0.3 + t * EMBER_RISE, sin(a) * r)
		_embers[i].scale = Vector3.ONE * (1.0 - t)


func _add(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color, 0.6)
	mi.position = pos
	add_child(mi)
	return mi
