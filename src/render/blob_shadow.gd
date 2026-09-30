class_name BlobShadow
extends Node3D
## Soft round shadow pinned to the floor under a fighter (design.md DS-VIS-01 low-end fallback):
## shown at LOW quality where the realtime sun shadow is off.

const LIFT := 0.02
const HEIGHT := 0.01
const RADIUS_RATIO := 1.3


func setup(config: GameConfig) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = config.fighter_radius * RADIUS_RATIO
	disc.bottom_radius = disc.top_radius
	disc.height = HEIGHT
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = ToonMaterials.translucent(DS.GROUND_SHADOW)
	add_child(mi)
	top_level = true
	visible = false


func follow(ground_point: Vector3) -> void:
	global_position = Vector3(ground_point.x, LIFT, ground_point.z)
