class_name StyleGear
extends RefCounted
## One fighter's style gear (design.md DS-VIS-02, Phase 5 T8 direction A). follow() reads the
## sim view every frame: the look (StyleGearCatalog) is keyed by the view's character and style,
## and is only worn when the drawn KayKit model is that character's (a classic fighter, or a
## slot model that does not match, keeps the default look). The hand gear hides while the hand
## holds an item (shared hand slot) and comes back after; headgear stays on.

## Sword and staff lean up instead of sticking out sideways across neighbours: turned at the
## grip about the hand slot's x then z axis (degrees). Measured on the ready idle: the sword tip
## ends ~1.7 m up beside the head; the staff steepens but keeps its orb out under the hat brim.
const TILT_DEGREES := {StyleGearCatalog.Gear.SWORD: Vector2(20.0, 40.0), StyleGearCatalog.Gear.STAFF: Vector2(0.0, 30.0)}
const SWORD_GROW := 1.15
const HANDS: Array[String] = ["handslot.l", "handslot.r"]

var _model: CharacterModel
var _animator: CharacterAnimator
var _worn: String = ""
var _revealed: Array[MeshInstance3D] = []
var _rest: Dictionary = {}  # revealed hand mesh -> its KayKit transform
var _built: Array[Node3D] = []
var _hand: Array[Node3D] = []
var _hands_busy: bool = false


func _init(model: CharacterModel, animator: CharacterAnimator) -> void:
	_model = model
	_animator = animator


## Wears / swaps / drops the look for this view and hides the hand gear while an item is held.
func follow(view: Dictionary) -> void:
	if _model == null:
		return
	var wanted := _wanted(view)
	if wanted != _worn:
		_undress()
		if not wanted.is_empty():
			_dress(wanted, String(view.get("style", "")))
	_set_hands_busy(int(view.get("item_kind", Fighter.NONE)) != Fighter.NONE)


## The character id whose gear is worn, or "" (default look).
func worn() -> String:
	return _worn


## Gloves or the revealed sword / staff: the nodes that hide while an item is held.
func hand_gear() -> Array[Node3D]:
	return _hand


func _wanted(view: Dictionary) -> String:
	var character := String(view.get("character", ""))
	if character != _model.character_id() or not StyleGearCatalog.CHARACTER.has(character):
		return ""
	return character


func _dress(character: String, style: String) -> void:
	var look := StyleGearCatalog.look_for(character, style)
	if look.is_empty():
		return
	_reveal(String(look["headgear"]))
	var gear := int(look["gear"])
	if gear == StyleGearCatalog.Gear.GLOVES:
		_gloves(float(look["glove_radius"]))
	else:
		_hand_mesh(String(look["hand_mesh"]), gear)
	if _animator != null:
		_animator.set_clip(AnimMap.Anim.IDLE, String(look["idle_clip"]))
	_worn = character
	_hands_busy = false


func _undress() -> void:
	for mesh: MeshInstance3D in _revealed:
		mesh.visible = false
		if _rest.has(mesh):
			mesh.transform = _rest[mesh]
	for node: Node3D in _built:
		node.get_parent().remove_child(node)
		node.queue_free()
	if _animator != null and not _worn.is_empty():
		_animator.reset_clip(AnimMap.Anim.IDLE)
	_revealed.clear()
	_rest.clear()
	_built.clear()
	_hand.clear()
	_worn = ""


func _set_hands_busy(busy: bool) -> void:
	if busy == _hands_busy:
		return
	_hands_busy = busy
	for node: Node3D in _hand:
		node.visible = not busy


func _gloves(radius: float) -> void:
	for bone: String in HANDS:
		var slot := _model.bone_slot(bone)
		if slot == null:
			push_warning("StyleGear: no bone slot %s" % bone)
			continue
		var glove := StyleGearParts.glove(radius)
		slot.add_child(glove)
		glove.scale = Vector3.ONE / maxf(_model.model_scale(), 0.0001)
		_built.append(glove)
		_hand.append(glove)


func _hand_mesh(mesh_name: String, gear: int) -> void:
	var mesh := _reveal(mesh_name)
	if mesh == null:
		return
	_rest[mesh] = mesh.transform
	var grow := SWORD_GROW if gear == StyleGearCatalog.Gear.SWORD else 1.0
	mesh.transform = StyleGearParts.tilted(mesh.transform, TILT_DEGREES[gear], grow)
	_hand.append(mesh)
	if gear == StyleGearCatalog.Gear.STAFF:
		var world_scale := mesh.global_transform.basis.get_scale().x if mesh.is_inside_tree() else _model.model_scale()
		_built.append(StyleGearParts.orb(mesh, world_scale))


## Shows a KayKit accessory hidden by CharacterCatalog, in the character toon material.
func _reveal(mesh_name: String) -> MeshInstance3D:
	var found := _model.find_children(mesh_name, "MeshInstance3D", true, false)
	if found.is_empty():
		push_warning("StyleGear: no mesh %s on %s" % [mesh_name, _model.character_id()])
		return null
	var mesh := found[0] as MeshInstance3D
	mesh.visible = true
	CharacterModel.apply_toon(mesh)
	_revealed.append(mesh)
	return mesh
