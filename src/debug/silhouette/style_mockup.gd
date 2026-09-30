class_name StyleMockup
extends RefCounted
## Phase 5 T8 gate (design.md DS-VIS-02): three debug-only style looks laid over a normal
## FighterView, so each fighting style can be judged by silhouette alone. Never used by the game:
## only scripts/capture_silhouette.gd and tests call it.
##   BASE  the current look (accessories hidden, plain idle)
##   A     gear: gloves for boxing, a big sword, staff + orb, style headgear (MockupGear)
##   B     color accent + glowing trim per style (MockupTrim)
##   C     stance per style + a small floating style icon (MockupStance)

enum Direction { BASE, A, B, C }
enum Style { BOXING, WEAPON, RANGED }

## Lineup order for the captures: boxing, boxing, weapon, ranged (CharacterCatalog slot indices).
const LINEUP: Array[int] = [1, 3, 0, 2]
const STYLE_OF := {"Barbarian": Style.BOXING, "Rogue": Style.BOXING, "Knight": Style.WEAPON, "Mage": Style.RANGED}
const STYLE_NAME := {Style.BOXING: "권투", Style.WEAPON: "무기", Style.RANGED: "원거리"}
const SPECIAL_NAME := {"Barbarian": "대지 강타", "Rogue": "돌진 연타", "Knight": "회전 베기", "Mage": "거대 화염구"}
const DEFAULT_CLIP := "Idle"
const POSE_SECONDS := 0.3


static func style_of(character: String) -> int:
	return int(STYLE_OF.get(character, Style.BOXING))


## Dresses one fighter for a direction and freezes it in that direction's idle pose.
## Returns the clip used for the pose ("" if the fighter has no character model).
static func apply(direction: int, view: FighterView, character: String) -> String:
	var model := view.model()
	if model == null:
		push_error("StyleMockup: fighter has no character model")
		return ""
	var style := style_of(character)
	var clip := DEFAULT_CLIP
	match direction:
		Direction.A:
			clip = MockupGear.dress(model, character, style)
		Direction.B:
			MockupTrim.dress(model, style)
		Direction.C:
			clip = MockupStance.dress(view, model, style)
	pose(model, clip)
	return clip


## Stops the fighter's AnimationTree and holds one frame of a clip (captures need a still pose).
static func pose(model: CharacterModel, clip: String) -> void:
	for tree: Node in model.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	var player := model.animation_player()
	if player == null or not player.has_animation(clip):
		push_error("StyleMockup: no clip %s" % clip)
		return
	player.play(clip)
	player.seek(POSE_SECONDS, true)
	player.pause()


## The KayKit BoneAttachment3D riding a bone (e.g. "handslot.l"), or null.
static func bone_slot(model: CharacterModel, bone: String) -> Node3D:
	for node: Node in model.find_children("*", "BoneAttachment3D", true, false):
		if (node as BoneAttachment3D).bone_name == bone:
			return node as Node3D
	return null


## Adds a child sized in world units under a scaled bone slot (the glb root is scaled to fit).
static func attach(model: CharacterModel, bone: String, child: Node3D) -> bool:
	var slot := bone_slot(model, bone)
	if slot == null:
		push_error("StyleMockup: no bone slot %s" % bone)
		return false
	slot.add_child(child)
	child.scale = Vector3.ONE / maxf(model.model_scale(), 0.0001)
	return true


## Flat unshaded material: every mesh under root turns into a pure silhouette.
static func silhouette(root: Node, color: Color) -> void:
	var mat := glow_material(color)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if node is Label3D:
			continue
		(node as GeometryInstance3D).material_override = mat
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Unshaded token-colored material for glowing trims, icons and silhouettes.
static func glow_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


static func mesh_node(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return node


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s
