class_name ChargeGlow
extends Node3D
## Heavy-charge glow (design.md DS-VFX-06): a warm glow orb around the fighter's hands that grows
## with the charge and pulses at full charge. Bloom (HIGH quality) makes it bleed.

const MIN_SCALE := 0.3
const MAX_SCALE := 1.0
const RADIUS := 0.35
const PULSE_HZ := 6.0
const PULSE_AMOUNT := 0.12

var _orb: MeshInstance3D
var _ratio: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	var s := SphereMesh.new()
	s.radius = RADIUS
	s.height = RADIUS * 2.0
	_orb = MeshInstance3D.new()
	_orb.mesh = s
	_orb.material_override = ToonMaterials.toon(DS.GLOW, 0.8)
	add_child(_orb)
	visible = false


func set_charge(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = _ratio > 0.0
	scale = Vector3.ONE * base_scale()


func base_scale() -> float:
	return lerpf(MIN_SCALE, MAX_SCALE, _ratio)


func _process(delta: float) -> void:
	if not visible or _ratio < 1.0:
		return
	_time += delta
	scale = Vector3.ONE * (base_scale() * (1.0 + PULSE_AMOUNT * sin(_time * TAU * PULSE_HZ)))
