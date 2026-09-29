class_name HitSpark
extends Node3D
## Hit puff v1 (design.md DS-VFX-01): a soft glow puff that swells and shrinks away; large hits
## add a burst of petals. Round shapes only (no sharp spark lines). Frees itself when done.

const SMALL_SCALE := 0.6
const LARGE_SCALE := 1.2
const START_SCALE := 0.2
const PETAL_COUNT := 12
const PETAL_SIZE := 0.08
const PETAL_SPEED := 4.0
const PETAL_GRAVITY := Vector3(0, -9.0, 0)
const PETAL_LIFETIME := 0.6
const LIFETIME := 0.8


func play(at: Vector3, large: bool) -> void:
	position = at
	var puff := MeshInstance3D.new()
	puff.mesh = SphereMesh.new()
	puff.material_override = ToonMaterials.toon(DS.GLOW)
	puff.scale = Vector3.ONE * START_SCALE
	add_child(puff)
	var peak := LARGE_SCALE if large else SMALL_SCALE
	var tw := create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * peak, DS.MOTION_FAST).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "scale", Vector3.ZERO, DS.MOTION_BASE).set_ease(Tween.EASE_IN)
	if large:
		add_child(_petals())
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _petals() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var petal := SphereMesh.new()
	petal.radius = PETAL_SIZE
	petal.height = PETAL_SIZE * 2.0
	petal.material = ToonMaterials.toon(DS.PETAL_PINK)
	p.mesh = petal
	p.amount = PETAL_COUNT
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = PETAL_LIFETIME
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = PETAL_SPEED * 0.5
	p.initial_velocity_max = PETAL_SPEED
	p.gravity = PETAL_GRAVITY
	p.emitting = true
	return p
