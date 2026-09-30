class_name MockupGear
extends RefCounted
## Direction A (Phase 5 T8 gate): the style reads from gear. Boxing = big round gloves on both
## hands (the Barbarian's bigger), weapon = the KayKit two-hand sword grown larger, ranged = the
## KayKit staff with a fire orb on top. Each character keeps its KayKit headgear for identity.

const GLOVE_RADIUS := {"Barbarian": 0.2, "Rogue": 0.155}
const CUFF_RATIO := 0.72
const CUFF_OFFSET := -0.7
const SWORD_SCALE := 1.15
const ORB_RADIUS := 0.13
const HEADGEAR := {"Barbarian": "Barbarian_Hat", "Rogue": "Rogue_Cape", "Knight": "Knight_Helmet", "Mage": "Mage_Hat"}
const HANDS: Array[String] = ["handslot.l", "handslot.r"]
## Sword and staff hang to the floor in the plain idle: the two-hand ready stance raises them.
const CLIP := {StyleMockup.Style.WEAPON: "2H_Melee_Idle", StyleMockup.Style.RANGED: "2H_Melee_Idle"}


## Dresses the model and returns the idle clip that shows the gear best.
static func dress(model: CharacterModel, character: String, style: int) -> String:
	reveal(model, String(HEADGEAR.get(character, "")))
	match style:
		StyleMockup.Style.BOXING:
			_gloves(model, float(GLOVE_RADIUS.get(character, 0.16)))
		StyleMockup.Style.WEAPON:
			var sword := reveal(model, "2H_Sword")
			if sword != null:
				sword.scale *= SWORD_SCALE
		StyleMockup.Style.RANGED:
			var staff := reveal(model, "2H_Staff")
			if staff != null:
				_orb(staff)
	return String(CLIP.get(style, StyleMockup.DEFAULT_CLIP))


## Shows a hidden KayKit accessory mesh with the character toon material. Null if missing.
static func reveal(model: CharacterModel, mesh_name: String) -> MeshInstance3D:
	if mesh_name.is_empty():
		return null
	var found := model.find_children(mesh_name, "MeshInstance3D", true, false)
	if found.is_empty():
		push_error("MockupGear: no mesh %s" % mesh_name)
		return null
	var mesh := found[0] as MeshInstance3D
	mesh.visible = true
	for i: int in mesh.get_surface_override_material_count():
		var src := mesh.get_active_material(i)
		var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
		mesh.set_surface_override_material(i, ToonMaterials.character(tex))
	return mesh


static func _gloves(model: CharacterModel, radius: float) -> void:
	for bone: String in HANDS:
		var glove := Node3D.new()
		glove.add_child(StyleMockup.mesh_node(StyleMockup.sphere(radius), ToonMaterials.toon(DS.DANGER, 0.35)))
		var cuff := StyleMockup.sphere(radius * CUFF_RATIO)
		glove.add_child(StyleMockup.mesh_node(cuff, ToonMaterials.toon(DS.UI_SURFACE, 0.35),
				Vector3(0.0, radius * CUFF_OFFSET, 0.0)))
		StyleMockup.attach(model, bone, glove)


## A glowing fire orb on the staff's head (the far end of its longest axis, by the gem).
static func _orb(staff: MeshInstance3D) -> void:
	var box := staff.get_aabb()
	var axis := box.get_longest_axis_index()
	var tip := box.get_center()
	tip[axis] = box.end[axis]
	var orb := Node3D.new()
	orb.position = tip
	orb.add_child(StyleMockup.mesh_node(StyleMockup.sphere(ORB_RADIUS), StyleMockup.glow_material(DS.FIRE)))
	orb.add_child(StyleMockup.mesh_node(StyleMockup.sphere(ORB_RADIUS * 0.55), StyleMockup.glow_material(DS.GLOW)))
	staff.add_child(orb)
	var s := staff.global_transform.basis.get_scale().x if staff.is_inside_tree() else 1.0
	orb.scale = Vector3.ONE / maxf(s, 0.0001)
