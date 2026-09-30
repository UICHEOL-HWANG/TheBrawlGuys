class_name KnockbackTrail
extends Node3D
## Knockback trail (design.md DS-VFX-04, GD-FEEL-04): each tick a launched fighter moves fast,
## a player-colored soft puff (plus a falling leaf at high intensity) is left behind and fades.
## Size follows the intensity (speed / trail_speed_full). Samples live in world space.

const SAMPLE_SIZE := 0.35
const SAMPLE_LIFETIME := 0.35
const LEAF_THRESHOLD := 0.6
const LEAF_SIZE := 0.08
const LEAF_FALL := 0.8


func add_sample(at: Vector3, intensity: float, color: Color, particle_scale: float) -> void:
	_spawn(at, SAMPLE_SIZE * lerpf(0.4, 1.0, intensity), color, Vector3.ZERO)
	if intensity >= LEAF_THRESHOLD and particle_scale >= 1.0:
		_spawn(at, LEAF_SIZE, DS.GRASS_MID, Vector3.DOWN * LEAF_FALL)


func _spawn(at: Vector3, size: float, color: Color, drift: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	mi.mesh = s
	mi.material_override = ToonMaterials.toon(color)
	mi.top_level = true
	add_child(mi)
	mi.global_position = at + Vector3.UP * 0.8
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ZERO, SAMPLE_LIFETIME).set_ease(Tween.EASE_IN)
	if drift != Vector3.ZERO:
		tw.tween_property(mi, "global_position", mi.global_position + drift, SAMPLE_LIFETIME)
	tw.chain().tween_callback(mi.queue_free)
