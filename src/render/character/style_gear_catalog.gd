class_name StyleGearCatalog
extends RefCounted
## Phase 5 style looks (design.md DS-VIS-02, T8 direction A): the style picks the gear kind
## (boxer = big round gloves, weapon = the KayKit two-hand sword, ranged = the KayKit staff with a
## fire orb) and the character picks its sizes and headgear. Keyed by the sim view's character
## and style ids; the classic fighter and unknown characters get no look ({}).

enum Gear { GLOVES, SWORD, STAFF }

const STYLE_GEAR := {
	StyleCatalog.BOXER: Gear.GLOVES, StyleCatalog.WEAPON: Gear.SWORD, StyleCatalog.RANGED: Gear.STAFF,
}
## Per character: headgear mesh turned back on, glove radius in m when boxing (Barbarian's
## bigger; the others only matter if a character ever changes style).
const CHARACTER := {
	CharacterData.BARBARIAN: {"headgear": "Barbarian_Hat", "glove_radius": 0.2},
	CharacterData.ROGUE: {"headgear": "Rogue_Cape", "glove_radius": 0.155},
	CharacterData.KNIGHT: {"headgear": "Knight_Helmet", "glove_radius": 0.16},
	CharacterData.MAGE: {"headgear": "Mage_Hat", "glove_radius": 0.16},
}
## KayKit hand meshes revealed per gear kind (hidden by CharacterCatalog in the default look).
const HAND_MESH := {Gear.SWORD: "2H_Sword", Gear.STAFF: "2H_Staff"}
## Idle clip per gear kind: boxers keep their fists up (the direction C guard), the sword and
## staff would drag on the floor in the plain idle so the two-hand ready stance raises them.
const IDLE_CLIP := {Gear.GLOVES: "Unarmed_Pose", Gear.SWORD: "2H_Melee_Idle", Gear.STAFF: "2H_Melee_Idle"}


## {"gear", "headgear", "glove_radius", "hand_mesh", "idle_clip"} or {} (no look).
static func look_for(character: String, style: String) -> Dictionary:
	if not CHARACTER.has(character) or not STYLE_GEAR.has(style):
		return {}
	var gear := int(STYLE_GEAR[style])
	var extra: Dictionary = CHARACTER[character]
	return {
		"gear": gear, "headgear": String(extra["headgear"]), "glove_radius": float(extra["glove_radius"]),
		"hand_mesh": String(HAND_MESH.get(gear, "")), "idle_clip": String(IDLE_CLIP[gear]),
	}
