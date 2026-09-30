class_name RespawnBeam
extends Node3D
## Respawn light pillar (design.md DS-VFX-06): a soft glow column from the respawn point down to
## the floor that narrows and fades. Frees itself.

const LIFETIME := 0.7
const RADIUS := 0.7


func play(at: Vector3) -> void:
	var height := maxf(at.y, 1.0)
	position = Vector3(at.x, height * 0.5, at.z)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = RADIUS
	c.bottom_radius = RADIUS
	c.height = height
	mi.mesh = c
	mi.material_override = ToonMaterials.translucent(DS.RESPAWN_BEAM)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.05, 1.0, 0.05), LIFETIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
