class_name CharacterSelectTracking
extends RefCounted
## character_selected props (Phase 5 T10, docs/tracking-plan.md §3.3) once every human is ready:
## one per slot, bots included (their characters were just drawn), humans with the device they
## confirmed with and how many cards they browsed. Coming back from the arena screen and locking
## the same line-up again sends nothing new (same_as).


## One props dictionary per setup slot, in slot order.
static func props(setup: MatchSetup, model: CharacterSelectModel, devices: SeatDevices) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in setup.slots:
		var seat := model.seat_of_slot(int(s["slot"]))
		var id := String(s["character"])
		var p := {"slot": int(s["slot"]), "character": id, "style": CharacterData.style_of(id),
			"is_bot": seat < 0}
		if seat >= 0:
			p["input_device"] = devices.device_of(seat)
			p["browse_count"] = model.browse(seat)
		else:
			p["input_device"] = String(s["input_device"])
		out.append(p)
	return out


## True when the same slots got the same characters as the last line-up sent.
static func same_as(last: Array[String], now: Array[String]) -> bool:
	return not last.is_empty() and last == now
