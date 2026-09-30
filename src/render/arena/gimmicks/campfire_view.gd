class_name CampfireView
extends GimmickView
## Lakeside campfire (burn_zone; design.md DS-VIS-04 "지속 대미지 = fire 발광 + 불티", DS-THM-02
## campfire glow): a stone ring, crossed logs and flickering layered flames with rising embers and
## a warm light, plus the burn radius glowing on the ground so the danger reads before touching.

const STONE_COUNT := 8
const STONE_RADIUS := 0.14
const LOG_RADIUS := 0.07
const LOG_LENGTH := 0.8
const LOG_TILT := 0.35
## Flame layers: [color, radius, height], outer to inner.
const FLAMES: Array[Array] = [[DS.FIRE, 0.3, 0.95], [DS.PETAL_YELLOW, 0.2, 0.7], [DS.GLOW, 0.11, 0.45]]
const FLICKER_HZ := 5.0
const FLICKER := 0.12
const RING_WIDTH := 0.14
const RING_FLATTEN := 0.05
const RING_LIFT := 0.02
const RING_PULSE_HZ := 1.2
const EMBER_COUNT := 10
const EMBER_RADIUS := 0.04
const EMBER_RISE := 1.6
const EMBER_PERIOD := 1.4
const LIGHT_ENERGY := 1.4
const LIGHT_RANGE := 4.0

var _flames: Array[MeshInstance3D] = []
var _embers: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _light: OmniLight3D
var _radius: float = 1.0


func _build(view: Dictionary) -> void:
	_radius = _area_radius(view)
	_build_ring()
	_build_pit()
	for f: Array in FLAMES:
		var s := SphereMesh.new()
		s.radius = float(f[1])
		s.height = float(f[2])
		_flames.append(_mesh(s, ToonMaterials.toon(f[0] as Color, 0.6), Vector3(0, float(f[2]) * 0.45, 0)))
	_build_embers()
	_light = OmniLight3D.new()
	_light.light_color = DS.FIRE
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.position.y = 0.8
	add_child(_light)


func _follow(_view: Dictionary, _delta: float) -> void:
	for i: int in _flames.size():
		var f := 1.0 + FLICKER * sin(_time * TAU * FLICKER_HZ + i * 2.1)
		_flames[i].scale = Vector3(2.0 - f, f, 2.0 - f)
	_light.light_energy = LIGHT_ENERGY * (1.0 + FLICKER * sin(_time * TAU * FLICKER_HZ * 0.7))
	var pulse := 1.0 + 0.04 * sin(_time * TAU * RING_PULSE_HZ)
	_ring.scale = Vector3(pulse, RING_FLATTEN, pulse)
	for i: int in _embers.size():
		var t := fposmod(_time / EMBER_PERIOD + float(i) / _embers.size(), 1.0)
		var a := TAU * float(i) / _embers.size()
		_embers[i].position = Vector3(cos(a) * 0.25 * (1.0 - t), 0.3 + t * EMBER_RISE, sin(a) * 0.25 * (1.0 - t))
		_embers[i].scale = Vector3.ONE * (1.0 - t)


func ring_radius() -> float:
	return _radius


func ember_count() -> int:
	return _embers.size()


func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = _radius - RING_WIDTH
	torus.outer_radius = _radius
	torus.rings = 48
	_ring = _mesh(torus, ToonMaterials.translucent(DS.FIRE_RING), Vector3(0, RING_LIFT, 0))
	var disc := CylinderMesh.new()
	disc.top_radius = _radius
	disc.bottom_radius = _radius
	disc.height = 0.01
	_mesh(disc, ToonMaterials.translucent(DS.FIRE_RING), Vector3(0, RING_LIFT * 0.5, 0))


func _build_pit() -> void:
	var stone := SphereMesh.new()
	stone.radius = STONE_RADIUS
	stone.height = STONE_RADIUS * 1.4
	for i: int in STONE_COUNT:
		var a := TAU * float(i) / STONE_COUNT
		var r := _radius * 0.62
		_mesh(stone, ToonMaterials.toon(DS.STONE_SHADE), Vector3(cos(a) * r, STONE_RADIUS * 0.5, sin(a) * r))
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = LOG_RADIUS
	log_mesh.bottom_radius = LOG_RADIUS
	log_mesh.height = LOG_LENGTH
	for i: int in 3:
		var mi := _mesh(log_mesh, ToonMaterials.toon(DS.BARK), Vector3(0, 0.12, 0))
		mi.rotation = Vector3(PI * 0.5 - LOG_TILT, TAU * i / 3.0, 0)


func _build_embers() -> void:
	var count := maxi(roundi(EMBER_COUNT * Quality.particle_scale(_config)), 1)
	var s := SphereMesh.new()
	s.radius = EMBER_RADIUS
	s.height = EMBER_RADIUS * 2.0
	for i: int in count:
		_embers.append(_mesh(s, ToonMaterials.toon(DS.FIRE, 0.6)))
