class_name SetupCodec
extends RefCounted
## MatchSetup <-> plain dictionary for WELCOME (online): mode, arena, seed, rule and per slot
## {slot, character, controller}. Received dictionaries are untrusted: wrong types or a setup that
## fails MatchSetup.validate() decode to null. for_client() re-labels the line-up from one
## client's point of view: its own slot is local, every other human is remote.


static func to_dict(setup: MatchSetup) -> Dictionary:
	var slots: Array = []
	for s: Dictionary in setup.slots:
		slots.append({"slot": int(s["slot"]), "character": String(s["character"]),
			"controller": String(s["controller"])})
	return {"mode": setup.mode, "arena": setup.arena_id, "seed": setup.seed, "rule": setup.rule, "slots": slots}


static func from_dict(d: Dictionary) -> MatchSetup:
	if typeof(d.get("mode")) != TYPE_STRING or typeof(d.get("arena")) != TYPE_STRING \
			or typeof(d.get("seed")) != TYPE_INT or typeof(d.get("rule")) != TYPE_STRING \
			or typeof(d.get("slots")) != TYPE_ARRAY or (d["slots"] as Array).size() > NetProtocol.MAX_SLOTS:
		return null
	var s := MatchSetup.new()
	s.mode = d["mode"]
	s.arena_id = d["arena"]
	s.seed = d["seed"]
	s.rule = d["rule"]
	for e: Variant in d["slots"]:
		var slot := _slot(e)
		if slot.is_empty():
			return null
		s.slots.append(slot)
	return s if s.validate().is_empty() else null


## The setup as client `own_slot` plays it: own slot local (keyboard until devices are known),
## other humans remote, bots stay bots.
static func for_client(setup: MatchSetup, own_slot: int) -> MatchSetup:
	var c := setup.copy()
	for i: int in c.slots.size():
		var s := c.slots[i]
		var controller := String(s["controller"])
		if int(s["slot"]) == own_slot:
			controller = MatchSetup.CONTROLLER_LOCAL
		elif controller == MatchSetup.CONTROLLER_LOCAL:
			controller = MatchSetup.CONTROLLER_REMOTE
		c.slots[i] = _entry(int(s["slot"]), controller, String(s["character"]))
	return c


static func _slot(e: Variant) -> Dictionary:
	if not (e is Dictionary):
		return {}
	var d: Dictionary = e
	if typeof(d.get("slot")) != TYPE_INT or typeof(d.get("character")) != TYPE_STRING \
			or typeof(d.get("controller")) != TYPE_STRING:
		return {}
	return _entry(d["slot"], d["controller"], d["character"])


static func _entry(slot: int, controller: String, character: String) -> Dictionary:
	var device := MatchSetup.INPUT_BOT if controller == MatchSetup.CONTROLLER_BOT else MatchSetup.INPUT_KEYBOARD
	return MatchSetup.slot_entry(slot, controller, device).merged({"character": character}, true)
