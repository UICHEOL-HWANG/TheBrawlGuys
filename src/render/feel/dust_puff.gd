class_name DustPuff
extends Node3D
## Landing dust (design.md DS-VFX-03): soft grass-and-dirt cloud puffs that swell outward and
## shrink away. Count and size follow the fall speed; LOW quality halves the count.

const MAX_PUFFS := 8
const MIN_PUFFS := 2
const PUFF_SIZE := 0.22
const SPREAD := 0.6
const LIFETIME := 0.45
const COLORS := [DS.GRASS_SUN, DS.DIRT, DS.GRASS]


func play(at: Vector3, intensity: float, particle_scale: float) -> void:
	position = at
	var count := maxi(roundi(lerpf(MIN_PUFFS, MAX_PUFFS, intensity) * particle_scale), 1)
	for i: int in count:
		var a := TAU * float(i) / count
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = PUFF_SIZE * (0.6 + 0.4 * intensity)
		s.height = s.radius * 1.2
		puff.mesh = s
		puff.material_override = ToonMaterials.toon(COLORS[i % COLORS.size()])
		puff.scale = Vector3.ONE * 0.3
		add_child(puff)
		var out := Vector3(cos(a), 0.15, sin(a)) * SPREAD * (0.5 + intensity)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "position", out, LIFETIME).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ZERO, LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
