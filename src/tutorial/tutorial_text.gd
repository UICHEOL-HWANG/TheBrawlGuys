class_name TutorialText
extends RefCounted
## The instruction line of each tutorial goal for the device the player holds (Phase 5 T11,
## DS-TOK-06): keyboard lines name P1's InputMap keys (KeyHintSource, so rebinding changes them),
## pad lines the face buttons of the pad's family (Xbox letters, PlayStation shapes — body font
## glyphs × ○ □ △), touch lines the on-screen buttons and stick. {jump} {light} {heavy} {guard}
## {grab} are filled per device, with the noun and its particle ({k_ro} 키로 · 버튼으로, {k_reul}
## 키를 · 버튼을) and the move control already inflected ({move_by} 방향키로 · 왼쪽 스틱으로).

const DEVICE_KEYBOARD := SelectPrompts.DEVICE_KEYBOARD
const DEVICE_GAMEPAD := SelectPrompts.DEVICE_GAMEPAD
const DEVICE_TOUCH := SelectPrompts.DEVICE_TOUCH
const ARROWS_TEXT := "방향키로"
const KEYS_MOVE_FORMAT := "%s 키로"
const PAD_MOVE_TEXT := "왼쪽 스틱으로"
const KEY_NOUNS := {"k_ro": "키로", "k_reul": "키를"}
const PAD_NOUNS := {"k_ro": "버튼으로", "k_reul": "버튼을"}
const PAD_XBOX := {"jump": "A", "light": "X", "heavy": "Y", "guard": "RB", "grab": "B"}
const PAD_PS := {"jump": "×", "light": "□", "heavy": "△", "guard": "R1", "grab": "○"}
const LINES := {
	TutorialSteps.G_MOVE: "{move_by} 이리저리 달려 보세요",
	TutorialSteps.G_JUMP: "{jump} {k_ro} 점프! 공중에서 한 번 더 누르면 2단 점프예요",
	TutorialSteps.G_LIGHT_HIT: "연습 상대에게 다가가 {light} {k_ro} 때려 보세요",
	TutorialSteps.G_CHARGED_HIT: "{heavy} {k_reul} 꾹 눌러 힘을 모았다가, 떼면서 맞혀 보세요",
	TutorialSteps.G_GUARD: "상대가 공격해 와요! {guard} {k_reul} 누르고 있으면 막을 수 있어요",
	TutorialSteps.G_GRAB: "상대 바로 앞에서 {grab} {k_ro} 붙잡아 보세요",
	TutorialSteps.G_THROW: "잡은 채로 {move_by} 방향을 정하고 {grab} {k_reul} 한 번 더!",
	TutorialSteps.G_PICKUP: "가운데 떨어진 방망이 옆에서 {grab} {k_ro} 주워요",
	TutorialSteps.G_ITEM_USE: "{light} {k_ro} 휘두르거나 {grab} {k_ro} 던져 보세요",
	TutorialSteps.G_SPECIAL: "게이지가 가득! {heavy}+{guard} {k_reul} 함께 눌러 필살기를 써 보세요",
}
## Touch has no key names: whole lines that point at the on-screen controls.
const TOUCH_LINES := {
	TutorialSteps.G_MOVE: "왼쪽 아래를 끌어 스틱으로 이리저리 달려 보세요",
	TutorialSteps.G_JUMP: "점프 버튼을 눌러 보세요. 공중에서 한 번 더 누르면 2단 점프예요",
	TutorialSteps.G_LIGHT_HIT: "연습 상대에게 다가가 공격 버튼을 톡 눌러 때려 보세요",
	TutorialSteps.G_CHARGED_HIT: "공격 버튼을 길게 눌러 힘을 모았다가, 떼면서 맞혀 보세요",
	TutorialSteps.G_GUARD: "상대가 공격해 와요! 가드 버튼을 누르고 있으면 막을 수 있어요",
	TutorialSteps.G_GRAB: "상대 바로 앞에서 잡기 버튼으로 붙잡아 보세요",
	TutorialSteps.G_THROW: "잡은 채로 스틱으로 방향을 정하고 잡기 버튼을 한 번 더!",
	TutorialSteps.G_PICKUP: "가운데 떨어진 방망이 옆에서 잡기 버튼으로 주워요",
	TutorialSteps.G_ITEM_USE: "공격 버튼으로 휘두르거나 잡기 버튼으로 던져 보세요",
	TutorialSteps.G_SPECIAL: "게이지가 가득! 공격을 길게 누른 채 가드도 눌러 보세요",
}


static func line(goal: String, device: String, family: String = SelectPrompts.FAMILY_XBOX,
		prefix: String = KeyHintSource.DEFAULT_PREFIX) -> String:
	if device == DEVICE_TOUCH:
		return String(TOUCH_LINES.get(goal, ""))
	var text := String(LINES.get(goal, ""))
	var names := _pad_names(family) if device == DEVICE_GAMEPAD else _key_names(prefix)
	return text.format(names)


static func _pad_names(family: String) -> Dictionary:
	var names: Dictionary = (PAD_PS if family == SelectPrompts.FAMILY_PS else PAD_XBOX).merged(PAD_NOUNS)
	names["move_by"] = PAD_MOVE_TEXT
	return names


## P1's keys; the move cluster reads "방향키로" while it is the arrows, else its four keys.
static func _key_names(prefix: String) -> Dictionary:
	var names := KEY_NOUNS.duplicate()
	for id: String in ["jump", "light", "heavy", "guard", "grab"]:
		names[id] = String(KeyHintSource.cap(id, prefix).get("text", ""))
	var arrows := true
	var keys := PackedStringArray()
	for id: String in KeyHintSource.MOVE_IDS:
		var cap := KeyHintSource.cap(id, prefix)
		arrows = arrows and cap.get("arrow", Vector2.ZERO) != Vector2.ZERO
		keys.append(String(cap.get("text", "")))
	names["move_by"] = ARROWS_TEXT if arrows else KEYS_MOVE_FORMAT % " ".join(keys)
	return names
