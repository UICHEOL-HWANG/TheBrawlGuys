class_name TutorialSteps
extends RefCounted
## The onboarding tutorial's missions (Phase 5 T11, PRD-UI-02), in play order. A step is one or
## more goals met one after another (grab, then throw); each goal names the KeyHintBar caps to
## ring (KeyHintSource ids) and the InputFrame buttons whose presses count as attempts. Step ids
## are the `step` values of the tutorial_* events (tracking-plan §3.3) — renaming one splits the
## Amplitude funnel, so they only ever get added.

const MOVE := "move"
const JUMP := "jump"
const LIGHT := "light_attack"
const HEAVY := "heavy_attack"
const GUARD := "guard"
const GRAB := "grab_throw"
const ITEM := "item"
const SPECIAL := "special"
const ORDER: Array[String] = [MOVE, JUMP, LIGHT, HEAVY, GUARD, GRAB, ITEM, SPECIAL]

## Goal ids (TutorialDetector).
const G_MOVE := "move"
const G_JUMP := "jump"
const G_LIGHT_HIT := "light_hit"
const G_CHARGED_HIT := "charged_hit"
const G_GUARD := "guard_block"
const G_GRAB := "grab"
const G_THROW := "throw"
const G_PICKUP := "item_pickup"
const G_ITEM_USE := "item_use"
const G_SPECIAL := "special"

const GOALS := {
	MOVE: [G_MOVE], JUMP: [G_JUMP], LIGHT: [G_LIGHT_HIT], HEAVY: [G_CHARGED_HIT], GUARD: [G_GUARD],
	GRAB: [G_GRAB, G_THROW], ITEM: [G_PICKUP, G_ITEM_USE], SPECIAL: [G_SPECIAL],
}
const TITLES := {
	MOVE: "이동", JUMP: "점프", LIGHT: "약공격", HEAVY: "강공격 · 모아치기", GUARD: "가드",
	GRAB: "잡기 · 던지기", ITEM: "아이템", SPECIAL: "필살기",
}
## Goal -> KeyHintBar cap ids to ring while that goal is the current one.
const KEYS := {
	G_MOVE: ["up", "left", "down", "right"], G_JUMP: ["jump"], G_LIGHT_HIT: ["light"],
	G_CHARGED_HIT: ["heavy"], G_GUARD: ["guard"], G_GRAB: ["grab"], G_THROW: ["grab"],
	G_PICKUP: ["grab"], G_ITEM_USE: ["light", "grab"], G_SPECIAL: ["special"],
}
## Goal -> TutorialAttempts button names whose presses count as a try.
const TRIES := {
	G_MOVE: ["move"], G_JUMP: ["jump"], G_LIGHT_HIT: ["light"], G_CHARGED_HIT: ["heavy"],
	G_GUARD: ["guard"], G_GRAB: ["grab"], G_THROW: ["grab"], G_PICKUP: ["grab"],
	G_ITEM_USE: ["light", "grab"], G_SPECIAL: ["special"],
}

## Goal -> TouchInput buttons the touch tutorial rings (the stick has none; the special is a long
## attack press plus guard).
const TOUCH := {
	G_JUMP: ["jump"], G_LIGHT_HIT: ["attack"], G_CHARGED_HIT: ["attack"], G_GUARD: ["guard"],
	G_GRAB: ["grab"], G_THROW: ["grab"], G_PICKUP: ["grab"], G_ITEM_USE: ["attack", "grab"],
	G_SPECIAL: ["attack", "guard"],
}


static func count() -> int:
	return ORDER.size()


static func id_at(index: int) -> String:
	return ORDER[index] if index >= 0 and index < ORDER.size() else ""


static func goals(step: String) -> Array:
	return GOALS.get(step, [])


static func title(step: String) -> String:
	return String(TITLES.get(step, ""))


static func keys(goal: String) -> Array:
	return KEYS.get(goal, [])


static func tries(goal: String) -> Array:
	return TRIES.get(goal, [])


static func touch_buttons(goal: String) -> Array:
	return TOUCH.get(goal, [])
