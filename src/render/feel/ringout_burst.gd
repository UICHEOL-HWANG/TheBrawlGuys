class_name RingoutBurst
extends Node3D
## Ring-out burst (design.md DS-VFX-05): over the lake a tall water splash of round droplets,
## elsewhere a star burst of round player-colored petals. Frees itself.

const LIFETIME := 0.9
const DROPS := 14
const PETALS := 18
const DROP_SIZE := 0.25
const PETAL_SIZE := 0.18
const SPLASH_HEIGHT := 4.0
const BURST_RADIUS := 3.0


func play(at: Vector3, splash: bool, color: Color, particle_scale: float) -> void:
	position = at
	var count := maxi(roundi((DROPS if splash else PETALS) * particle_scale), 4)
	for i: int in count:
		var a := TAU * float(i) / count
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = DROP_SIZE if splash else PETAL_SIZE
		s.height = s.radius * 2.0
		mi.mesh = s
		mi.material_override = ToonMaterials.toon((DS.WATER if i % 2 == 0 else DS.SKY) if splash else color, 0.3)
		add_child(mi)
		var target := Vector3(cos(a) * 0.8, SPLASH_HEIGHT * (0.6 + 0.4 * float(i % 3) / 2.0), sin(a) * 0.8) if splash \
				else Vector3(cos(a), 0.4 * sin(a * 3.0), sin(a)) * BURST_RADIUS
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", target, LIFETIME * 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ZERO, LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
