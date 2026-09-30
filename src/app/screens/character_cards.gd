class_name CharacterCards
extends RefCounted
## What the character select shows per character (Phase 5 T9, DS-CMP-08, 2026-09-30 decision):
## the Korean name, the style and the special by name, and the KayKit model for the portrait.
## Styles and specials come from CharacterData, their names from STYLE_NAMES and the cut-in
## banner's SpecialCutInBanner.NAMES (one spelling everywhere).

const TITLES := {
	CharacterData.BARBARIAN: "바바리안",
	CharacterData.ROGUE: "로그",
	CharacterData.KNIGHT: "나이트",
	CharacterData.MAGE: "메이지",
}
const STYLE_NAMES := {
	StyleCatalog.BOXER: "권투",
	StyleCatalog.WEAPON: "무기",
	StyleCatalog.RANGED: "원거리",
}
## Card order: the two boxers, then weapon, then ranged.
const ORDER: Array[String] = [CharacterData.BARBARIAN, CharacterData.ROGUE, CharacterData.KNIGHT,
	CharacterData.MAGE]
const CLASSIC_TITLE := "기본 파이터"
const CAPTION_FORMAT := "%s 스타일\n필살기 · %s"


## One entry per character in card order: {id, title, caption, style, style_name, special_name, model}.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ORDER:
		out.append(entry(id))
	return out


static func entry(id: String) -> Dictionary:
	var style := CharacterData.style_of(id)
	var style_name := String(STYLE_NAMES.get(style, style))
	var special_name := String(SpecialCutInBanner.NAMES.get(CharacterData.special_of(id), ""))
	return {"id": id, "title": title_of(id), "caption": CAPTION_FORMAT % [style_name, special_name],
		"style": style, "style_name": style_name, "special_name": special_name,
		"model": CharacterCatalog.for_character(id, 0)}


static func title_of(id: String) -> String:
	return String(TITLES.get(id, CLASSIC_TITLE))
