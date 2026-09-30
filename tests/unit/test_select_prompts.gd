extends GutTest
## Select screen button prompts (design.md DS-TOK-06 입력 장치 프롬프트): the hint under each
## player shows the glyphs of the device that player is using — P1 keys, P2 keys or a pad
## (Xbox letters, PlayStation shapes) — read from InputMap so rebinding changes them.

const P := preload("res://src/ui/select_prompts.gd")


func before_all() -> void:
	InputBindings.apply()


func _caps(prompt: Dictionary) -> Array:
	var out: Array = []
	for c: Dictionary in prompt["caps"]:
		out.append(c.get("glyph", c.get("text", c.get("arrow"))))
	return out


func test_p1_keyboard_shows_arrows_z_and_x() -> void:
	var rows := P.for_player("p1", P.DEVICE_KEYBOARD)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["label"], P.LABEL_BROWSE)
	assert_eq(_caps(rows[0]), [Vector2.LEFT, Vector2.RIGHT])
	assert_eq([rows[1]["label"], _caps(rows[1])], [P.LABEL_CONFIRM, ["Z"]])
	assert_eq([rows[2]["label"], _caps(rows[2])], [P.LABEL_CANCEL, ["X"]])


func test_p2_keyboard_shows_its_own_keys() -> void:
	var rows := P.for_player("p2", P.DEVICE_KEYBOARD)
	assert_eq(_caps(rows[0]), ["A", "D"])
	assert_eq(_caps(rows[1]), ["F"])
	assert_eq(_caps(rows[2]), ["G"])


func test_gamepads_show_face_buttons_by_family() -> void:
	var xbox := P.for_player("p2", P.DEVICE_GAMEPAD, P.pad_family("Xbox Series Controller"))
	assert_eq(_caps(xbox[0]), [P.GLYPH_DPAD])
	assert_eq(_caps(xbox[1]), [P.GLYPH_A])
	assert_eq(_caps(xbox[2]), [P.GLYPH_B])
	var ps := P.for_player("p1", P.DEVICE_GAMEPAD, P.pad_family("PS5 Controller"))
	assert_eq(_caps(ps[1]), [P.GLYPH_CROSS])
	assert_eq(_caps(ps[2]), [P.GLYPH_CIRCLE])
	assert_eq(P.pad_family("DualShock 4"), P.FAMILY_PS)
	assert_eq(P.pad_family(""), P.FAMILY_XBOX, "unknown pads read as Xbox")


func test_touch_has_no_key_prompts() -> void:
	assert_eq(P.for_player("p1", P.DEVICE_TOUCH).size(), 0)
