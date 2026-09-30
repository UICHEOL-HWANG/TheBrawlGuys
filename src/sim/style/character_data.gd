class_name CharacterData
extends RefCounted
## Character -> style + unique special (PRD §6.2, 2026-09-30 user decision). Ids are lowercase;
## resolve() also accepts the render names ("Knight"). DEFAULT ("") is the Phase 1-4 classic
## fighter with no special, used when a slot has no character.

const DEFAULT := ""
const BARBARIAN := "barbarian"
const ROGUE := "rogue"
const KNIGHT := "knight"
const MAGE := "mage"
const IDS: Array[String] = [BARBARIAN, ROGUE, KNIGHT, MAGE]
const TABLE := {
	BARBARIAN: {"style": StyleCatalog.BOXER, "special": SpecialCatalog.GROUND_SLAM},
	ROGUE: {"style": StyleCatalog.BOXER, "special": SpecialCatalog.DASH_RUSH},
	KNIGHT: {"style": StyleCatalog.WEAPON, "special": SpecialCatalog.SPIN_SLASH},
	MAGE: {"style": StyleCatalog.RANGED, "special": SpecialCatalog.BIG_FIREBALL},
}


## The character id for `name` (case-insensitive); unknown names warn and fall back to DEFAULT.
static func resolve(name: String) -> String:
	var id := name.to_lower()
	if id == DEFAULT or TABLE.has(id):
		return id
	push_warning("CharacterData: unknown character '%s', using the classic fighter" % name)
	return DEFAULT


static func style_of(id: String) -> String:
	return String((TABLE[id] as Dictionary)["style"]) if TABLE.has(id) else StyleCatalog.CLASSIC


## The character's special id, or "" (no special).
static func special_of(id: String) -> String:
	return String((TABLE[id] as Dictionary)["special"]) if TABLE.has(id) else ""
