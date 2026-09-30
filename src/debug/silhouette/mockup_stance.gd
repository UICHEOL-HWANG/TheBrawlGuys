class_name MockupStance
extends RefCounted
## Direction C (Phase 5 T8 gate): the style reads from body language plus a small floating icon.
## Each style idles in its own KayKit clip (boxing guard, two-hand ready stance, casting hands)
## and a fist / sword / fireball mark (StyleIcon) floats over the head.

const CLIP := {
	StyleMockup.Style.BOXING: "Unarmed_Pose",
	StyleMockup.Style.WEAPON: "Block",
	StyleMockup.Style.RANGED: "Spellcast_Raise",
}
const ICON_LIFT := 0.45


static func clip_for(style: int) -> String:
	return String(CLIP.get(style, StyleMockup.DEFAULT_CLIP))


## Adds the floating icon and returns the stance clip to pose in.
static func dress(view: FighterView, model: CharacterModel, style: int) -> String:
	var icon := StyleIcon.build(style)
	icon.position = Vector3(0.0, model.visible_height() + ICON_LIFT, 0.0)
	view.add_child(icon)
	return clip_for(style)
