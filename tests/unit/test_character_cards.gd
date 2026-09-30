extends GutTest
## What the character select shows per character (Phase 5 T9, DS-CMP-08, 2026-09-30 decision):
## Barbarian 권투 "대지 강타", Rogue 권투 "돌진 연타", Knight 무기 "회전 베기", Mage 원거리
## "거대 화염구" — each card names the character, its style and its special, with its own model.


func test_four_characters_in_order_with_style_and_special() -> void:
	var cards := CharacterCards.entries()
	var ids: Array[String] = []
	for c: Dictionary in cards:
		ids.append(String(c["id"]))
	assert_eq(ids, [CharacterData.BARBARIAN, CharacterData.ROGUE, CharacterData.KNIGHT, CharacterData.MAGE])
	var expected := [["권투", "대지 강타"], ["권투", "돌진 연타"], ["무기", "회전 베기"], ["원거리", "거대 화염구"]]
	for i: int in cards.size():
		assert_eq(cards[i]["style_name"], expected[i][0])
		assert_eq(cards[i]["special_name"], expected[i][1])
		assert_string_contains(String(cards[i]["caption"]), expected[i][0])
		assert_string_contains(String(cards[i]["caption"]), expected[i][1])
		assert_eq(cards[i]["style"], CharacterData.style_of(ids[i]))
		assert_false(String(cards[i]["title"]).is_empty())
		assert_eq(String((cards[i]["model"] as Dictionary)["name"]).to_lower(), ids[i], "the card shows its own model")


func test_title_of_names_a_character_or_the_classic_fighter() -> void:
	assert_eq(CharacterCards.title_of(CharacterData.KNIGHT), CharacterCards.entry(CharacterData.KNIGHT)["title"])
	assert_eq(CharacterCards.title_of(CharacterData.DEFAULT), CharacterCards.CLASSIC_TITLE)
