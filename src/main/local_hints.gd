class_name LocalHints
extends RefCounted
## Local-player touch hints (Phase 2): grab button highlight, the grab target ring and disabled
## touch buttons while KO or after the match. No local slot (bots only) = everything off.


static func update(view: Dictionary, local_slot: int, config: GameConfig, touch: TouchInput, hint: GrabHint) -> void:
	if local_slot < 0:
		touch.set_enabled(false)
		touch.set_grab_highlight(false)
		hint.hide_hint()
		return
	var me: Dictionary = view["fighters"][local_slot]
	var active := int(me["state"]) != Fighter.State.KO and not bool(view["match_over"])
	touch.set_enabled(active)
	var ctx := GrabContext.evaluate(view, local_slot, config)
	var kind := int(ctx["kind"])
	touch.set_grab_highlight(active and kind != GrabContext.Kind.NONE)
	if active and (kind == GrabContext.Kind.ITEM or kind == GrabContext.Kind.FIGHTER):
		hint.show_at(ctx["pos"])
	else:
		hint.hide_hint()
