class_name SelectPrompts
extends RefCounted
## Button prompts of the select screens (design.md DS-TOK-06 입력 장치 프롬프트): per player and
## device, the rows "고르기 / 확정 / 취소" with the caps to press. Keyboard caps come from InputMap
## (KeyHintSource), so rebinding changes them; pads show a d-pad and the face buttons of their
## family (Xbox letters A / B, PlayStation cross / circle — drawn by PadGlyph). Touch has none.
## Row: {label, caps: [{text} | {arrow: Vector2} | {glyph}]}.

const DEVICE_KEYBOARD := "keyboard"
const DEVICE_GAMEPAD := "gamepad"
const DEVICE_TOUCH := "touch"
const FAMILY_XBOX := "xbox"
const FAMILY_PS := "ps"
const PS_NAMES: Array[String] = ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]
const GLYPH_DPAD := "dpad"
const GLYPH_A := "a"
const GLYPH_B := "b"
const GLYPH_CROSS := "cross"
const GLYPH_CIRCLE := "circle"
const LABEL_BROWSE := "고르기"
const LABEL_CONFIRM := "확정"
const LABEL_CANCEL := "취소"


static func for_player(prefix: String, device: String, family: String = FAMILY_XBOX) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	match device:
		DEVICE_GAMEPAD:
			var ps := family == FAMILY_PS
			rows.append(_row(LABEL_BROWSE, [{"glyph": GLYPH_DPAD}]))
			rows.append(_row(LABEL_CONFIRM, [{"glyph": GLYPH_CROSS if ps else GLYPH_A}]))
			rows.append(_row(LABEL_CANCEL, [{"glyph": GLYPH_CIRCLE if ps else GLYPH_B}]))
		DEVICE_KEYBOARD:
			rows.append(_row(LABEL_BROWSE, [_key_cap(prefix, "left"), _key_cap(prefix, "right")]))
			rows.append(_row(LABEL_CONFIRM, [_key_cap(prefix, "light")]))
			rows.append(_row(LABEL_CANCEL, [_key_cap(prefix, "heavy")]))
	return rows


## The pad's glyph family from Input.get_joy_name (unknown pads read as Xbox).
static func pad_family(joy_name: String) -> String:
	var lower := joy_name.to_lower()
	for n: String in PS_NAMES:
		if lower.contains(n):
			return FAMILY_PS
	return FAMILY_XBOX


static func _key_cap(prefix: String, action_name: String) -> Dictionary:
	var cap := KeyHintSource.cap(action_name, prefix)
	var arrow: Vector2 = cap.get("arrow", Vector2.ZERO)
	return {"arrow": arrow} if arrow != Vector2.ZERO else {"text": String(cap.get("text", ""))}


static func _row(label: String, caps: Array) -> Dictionary:
	return {"label": label, "caps": caps}
