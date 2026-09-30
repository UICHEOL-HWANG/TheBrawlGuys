class_name CharacterCatalog
extends RefCounted
## KayKit Character Pack: Adventurers 1.0 (CC0, ASSETS.md) per player slot (context F3).
## Accessory meshes (weapons, shields, hats, capes) are hidden: fighters brawl bare-handed and
## carried items use FighterView's own hand mesh. Names come from scripts/list_animations.gd.

const DIR := "res://assets/characters/kaykit/"
const CHARACTERS: Array[Dictionary] = [
	{
		"name": "Knight", "path": DIR + "Knight.glb",
		"hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield",
			"1H_Sword", "2H_Sword", "Knight_Helmet", "Knight_Cape"],
	},
	{
		"name": "Barbarian", "path": DIR + "Barbarian.glb",
		"hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug",
			"Barbarian_Hat", "Barbarian_Cape"],
	},
	{
		"name": "Mage", "path": DIR + "Mage.glb",
		"hide": ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff", "Mage_Hat", "Mage_Cape"],
	},
	{
		"name": "Rogue", "path": DIR + "Rogue.glb",
		"hide": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable", "Rogue_Cape"],
	},
]


static func for_player(index: int) -> Dictionary:
	return CHARACTERS[posmod(index, CHARACTERS.size())]


## The model of a CharacterData id (Phase 5 T9: the chosen character, whatever the slot); the
## classic fighter ("" or unknown) keeps the slot's model.
static func for_character(character_id: String, index: int) -> Dictionary:
	for c: Dictionary in CHARACTERS:
		if String(c["name"]).to_lower() == character_id:
			return c
	return for_player(index)
