class_name GrabHint
extends Node3D
## "Grab can act on this" marker (design.md DS-VFX-02): a petal-yellow ring pulsing softly on
## the ground under the item or fighter the local player's grab button would take.

const RING_INNER_RATIO := 1.2
const RING_OUTER_RATIO := 1.5
const RING_FLATTEN := 0.06
const RING_LIFT := 0.03
const PULSE_HZ := 1.5
const PULSE_SCALE := 0.1

var _ring: MeshInstance3D
var _time: float = 0.0


func setup(config: GameConfig) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = config.fighter_radius * RING_OUTER_RATIO
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ToonMaterials.toon(DS.PETAL_YELLOW)
	_ring.position.y = RING_LIFT
	_ring.scale = Vector3(1.0, RING_FLATTEN, 1.0)
	add_child(_ring)
	visible = false


func show_at(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	visible = true


func hide_hint() -> void:
	visible = false


func is_shown() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible or _ring == null:
		return
	_time += delta
	var s := 1.0 + PULSE_SCALE * sin(_time * TAU * PULSE_HZ)
	_ring.scale = Vector3(s, RING_FLATTEN, s)
