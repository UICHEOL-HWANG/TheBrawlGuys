class_name CharacterModel
extends Node3D
## One KayKit character (context F3, F6): the glb scene with every visible surface switched to
## the soft toon character material, accessories hidden, scaled so its rest-pose height matches
## the fighter capsule and its feet sit at y = 0. Drawing only; the capsule stays the hitbox.

## Extra yaw if the model's front is not +Z (checked against a screenshot in Task 5).
const FACING_OFFSET := 0.0

var _root: Node3D
var _player: AnimationPlayer


func setup(entry: Dictionary, config: GameConfig) -> bool:
	var path := String(entry["path"])
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("CharacterModel: cannot load %s" % entry["path"])
		return false
	_root = scene.instantiate() as Node3D
	add_child(_root)
	_root.rotation.y = FACING_OFFSET
	var players := _root.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if players.size() > 0 else null
	var hidden: Array = entry["hide"]
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if hidden.has(String(mesh.name)):
			mesh.visible = false
		else:
			_apply_toon(mesh)
	_fit(config.fighter_height)
	return true


func animation_player() -> AnimationPlayer:
	return _player


func visible_height() -> float:
	return _bounds().size.y


func foot_y() -> float:
	return _bounds().position.y


static func _apply_toon(mesh: MeshInstance3D) -> void:
	for i: int in mesh.get_surface_override_material_count():
		var src := mesh.get_active_material(i)
		var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
		mesh.set_surface_override_material(i, ToonMaterials.character(tex))


func _fit(target_height: float) -> void:
	var b := _bounds()
	if b.size.y <= 0.0001:
		return
	var s := target_height / b.size.y
	_root.scale = Vector3.ONE * s
	_root.position.y -= _bounds().position.y


## Rest-pose bounds of the visible meshes in this node's space.
func _bounds() -> AABB:
	var inv := global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue
		var box := inv * mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
