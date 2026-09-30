class_name CharacterModel
extends Node3D
## One KayKit character (context F3, F6): the glb scene with every visible surface switched to
## the soft toon character material, accessories hidden, scaled so its rest-pose height matches
## the fighter capsule and its feet sit at y = 0. Drawing only; the capsule stays the hitbox.

## Extra yaw if the model's front is not +Z (checked against a screenshot in Task 5).
const FACING_OFFSET := 0.0
## KayKit's right-hand weapon bone; carried items ride on it (HeldItem).
const HAND_BONE := "handslot.r"

var _root: Node3D
var _player: AnimationPlayer
var _character_id: String = ""


func setup(entry: Dictionary, config: GameConfig) -> bool:
	var path := String(entry["path"])
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("CharacterModel: cannot load %s" % entry["path"])
		return false
	_root = scene.instantiate() as Node3D
	_character_id = String(entry.get("name", "")).to_lower()
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
			apply_toon(mesh)
	_fit(config.fighter_height)
	return true


func animation_player() -> AnimationPlayer:
	return _player


## Lowercase character id of the loaded glb ("knight"), matching CharacterData ids.
func character_id() -> String:
	return _character_id


## The right-hand weapon slot of the KayKit rig (BoneAttachment3D on handslot.r), or null.
func hand_slot() -> Node3D:
	return bone_slot(HAND_BONE)


## The KayKit BoneAttachment3D riding a bone (e.g. "handslot.l", "head"), or null.
func bone_slot(bone: String) -> Node3D:
	if _root == null:
		return null
	for node: Node in _root.find_children("*", "BoneAttachment3D", true, false):
		if (node as BoneAttachment3D).bone_name == bone:
			return node as Node3D
	return null


## Uniform scale applied to fit the glb to the fighter height.
func model_scale() -> float:
	return _root.scale.x if _root != null else 1.0


func visible_height() -> float:
	return _bounds().size.y


func foot_y() -> float:
	return _bounds().position.y


## Switches every surface of a KayKit mesh to the soft toon character material.
static func apply_toon(mesh: MeshInstance3D) -> void:
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
