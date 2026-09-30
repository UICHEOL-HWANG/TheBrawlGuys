class_name GuardBubble
extends MeshInstance3D
## The soap bubble around a guarding fighter (DS-VFX-02): translucent sphere at mid-height,
## shown while the fighter guards, wobbles when a guarded hit lands. Drawing only.

const RADIUS_RATIO := 0.62
const WOBBLE_SQUASH := Vector3(1.12, 0.88, 1.12)


func setup(config: GameConfig) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = config.fighter_height * RADIUS_RATIO
	sphere.height = sphere.radius * 2.0
	mesh = sphere
	material_override = ToonMaterials.translucent(DS.GUARD_BUBBLE)
	position.y = config.fighter_height * 0.5
	visible = false


func wobble() -> void:
	scale = WOBBLE_SQUASH
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, DS.MOTION_SQUISH).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
