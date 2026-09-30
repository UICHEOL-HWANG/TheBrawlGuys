class_name MushroomPadView
extends GimmickView
## Bounce mushroom (bounce_pad; design.md DS-VIS-04 "튕김 버섯 = 말랑하게 숨 쉬는 모션",
## DS-THM-02 self-glowing mushrooms): a low glowing cap with light spots that breathes softly,
## squashes flat and springs back when someone bounces off it, and a rebound hint — a pulsing
## yellow ring on the ground and little arrows bobbing upward over the cap.

const CAP_HEIGHT := 0.7
const GILL_WIDTH := 0.12
const SPOTS: Array[Vector3] = [Vector3(0.0, 0.33, 0.0), Vector3(0.5, 0.24, 0.2), Vector3(-0.35, 0.25, 0.45),
		Vector3(-0.3, 0.26, -0.45), Vector3(0.3, 0.26, -0.5)]
const SPOT_RADIUS := 0.14
const BREATH_HZ := 0.6
const BREATH := 0.07
const SQUASH := Vector3(1.2, 0.5, 1.2)
const SQUASH_TIME := 0.45
const ARROW_COUNT := 3
const ARROW_RADIUS := 0.13
const ARROW_HEIGHT := 0.2
const ARROW_RING := 0.45
const ARROW_BOB := 0.35
const ARROW_HZ := 0.9
const HINT_LIFT := 0.02
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 2.6

var _cap: Node3D
var _hint: MeshInstance3D
var _arrows: Array[MeshInstance3D] = []
var _squash_left: float = 0.0
var _radius: float = 1.0


func on_event(e: Dictionary) -> void:
	if String(e.get("type", "")) == "bounce" and int(e.get("pad", -1)) == gimmick_id:
		_squash_left = SQUASH_TIME


func squashing() -> bool:
	return _squash_left > 0.0


func cap_scale() -> Vector3:
	return _cap.scale


func _build(view: Dictionary) -> void:
	_radius = _area_radius(view)
	var color := DS.PETAL_PINK if gimmick_id % 2 == 0 else DS.BERRY
	_cap = Node3D.new()
	add_child(_cap)
	var dome := SphereMesh.new()
	dome.radius = _radius
	dome.height = CAP_HEIGHT
	_mesh(dome, ToonMaterials.toon(color, 0.5), Vector3.ZERO, _cap)
	var gill := TorusMesh.new()
	gill.inner_radius = _radius - GILL_WIDTH
	gill.outer_radius = _radius + 0.02
	var ring := _mesh(gill, ToonMaterials.toon(DS.STONE_CREAM), Vector3(0, 0.02, 0), _cap)
	ring.scale = Vector3(1, 0.4, 1)
	var spot := SphereMesh.new()
	spot.radius = SPOT_RADIUS
	spot.height = SPOT_RADIUS
	for s: Vector3 in SPOTS:
		_mesh(spot, ToonMaterials.toon(DS.GLOW), s * Vector3(_radius, 1, _radius), _cap)
	_build_hint()
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.position.y = 0.6
	add_child(light)


func _build_hint() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = _radius + 0.05
	torus.outer_radius = _radius + 0.22
	_hint = _mesh(torus, ToonMaterials.translucent(DS.BOUNCE_RING), Vector3(0, HINT_LIFT, 0))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = ARROW_RADIUS
	cone.height = ARROW_HEIGHT
	for i: int in ARROW_COUNT:
		_arrows.append(_mesh(cone, ToonMaterials.toon(DS.PETAL_YELLOW, 0.5)))


func _follow(_view: Dictionary, delta: float) -> void:
	var breath := 1.0 + BREATH * sin(_time * TAU * BREATH_HZ + gimmick_id)
	if _squash_left > 0.0:
		_squash_left = maxf(_squash_left - delta, 0.0)
		var t := 1.0 - _squash_left / SQUASH_TIME
		var spring := exp(-5.0 * t) * cos(t * TAU * 1.5)  # 1 at the hit, wobbles back to 0
		_cap.scale = Vector3.ONE.lerp(SQUASH, spring)
	else:
		_cap.scale = Vector3(1.0 / sqrt(breath), breath, 1.0 / sqrt(breath))
	var pulse := 1.0 + 0.06 * sin(_time * TAU * ARROW_HZ)
	_hint.scale = Vector3(pulse, 0.08, pulse)
	for i: int in _arrows.size():
		var t := fposmod(_time * ARROW_HZ + float(i) / _arrows.size(), 1.0)
		var a := TAU * float(i) / _arrows.size() + _time * 0.5
		_arrows[i].position = Vector3(cos(a) * ARROW_RING, CAP_HEIGHT * 0.6 + t * ARROW_BOB, sin(a) * ARROW_RING)
		_arrows[i].scale = Vector3.ONE * (1.0 - t * 0.6)
