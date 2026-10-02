extends GutTest
## Nickname rules (onboarding, design.md DS-LAY-03): trimmed, inner spaces collapsed, 2..12
## characters, no control characters; OAuth display names are cut down to a usable prefill.


func test_clean_trims_and_collapses_spaces() -> void:
	assert_eq(Nickname.clean("  브롤   왕  "), "브롤 왕")
	assert_eq(Nickname.clean("\t탭\n"), "탭")


func test_length_bounds() -> void:
	assert_ne(Nickname.error("a"), "", "one character is too short")
	assert_eq(Nickname.error("ab"), "")
	assert_eq(Nickname.error("가나다라마바사아자차카타"), "", "12 characters fit")
	assert_ne(Nickname.error("가나다라마바사아자차카타파"), "", "13 is too long")
	assert_ne(Nickname.error("   "), "", "spaces only is empty")


func test_length_counts_after_cleaning() -> void:
	assert_eq(Nickname.error("  ab  "), "")
	assert_true(Nickname.is_valid(" 브롤왕 "))


func test_control_characters_are_refused() -> void:
	assert_ne(Nickname.error("ab" + char(7)), "")
	assert_ne(Nickname.error("a" + char(127) + "b"), "")


func test_errors_are_player_facing_korean() -> void:
	assert_eq(Nickname.error(""), Nickname.TOO_SHORT)
	assert_eq(Nickname.error("가나다라마바사아자차카타파"), Nickname.TOO_LONG)
	assert_eq(Nickname.error("ab" + char(1)), Nickname.BAD_CHAR)


func test_prefill_from_a_display_name() -> void:
	assert_eq(Nickname.prefill("  Kim  Minsu "), "Kim Minsu")
	assert_eq(Nickname.prefill("Alexandria Ocasio-Cortez"), "Alexandria O", "cut to 12, trailing space trimmed")
	assert_eq(Nickname.prefill(""), "")
	assert_eq(Nickname.prefill("x"), "", "too short to use")


func test_invisible_and_direction_characters_are_refused() -> void:
	for code: int in [0x200B, 0x200D, 0x202E, 0x2066, 0x2028, 0x2029, 0x0085, 0xFEFF]:
		assert_eq(Nickname.error("ab" + char(code)), Nickname.BAD_CHAR, "U+%04X" % code)
	assert_eq(Nickname.error(char(0x200B) + char(0x200B)), Nickname.BAD_CHAR, "zero-width only")


func test_other_spaces_collapse_like_spaces() -> void:
	assert_eq(Nickname.clean("a\tb"), "a b")
	assert_eq(Nickname.clean("a" + char(0x00A0) + char(0x3000) + "b"), "a b")
	assert_true(Nickname.is_valid("a\tb"), "a tab between words is just a space")
