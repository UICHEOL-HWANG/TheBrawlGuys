class_name LobbyLineup
extends RefCounted
## LobbyModel slots -> what a match needs (split out of LobbyModel): the MatchSetup line-up
## (occupied slots in order; the team rule fills up to four with bots), the peer -> slot map and
## the slot -> nickname map. Every device builds the same line-up from the same lobby state.


static func setup(slots: Array[Dictionary], rule: String, arena: String, local_peer: int, seed: int) -> MatchSetup:
	var out := MatchSetup.new()
	out.mode = MatchSetup.MODE_ONLINE
	out.seed = seed
	out.rule = rule
	out.arena_id = arena
	for s: Dictionary in slots:
		var peer := int(s["peer"])
		if peer == LobbyModel.EMPTY:
			continue
		var controller := MatchSetup.CONTROLLER_BOT if peer == LobbyModel.BOT else (
				MatchSetup.CONTROLLER_LOCAL if peer == local_peer else MatchSetup.CONTROLLER_REMOTE)
		var entry := MatchSetup.slot_entry(out.slots.size(), controller,
				PlatformEnv.default_input_device() if peer == local_peer else MatchSetup.INPUT_BOT)
		entry["character"] = String(s["character"])
		out.slots.append(entry)
	while rule == MatchRules.TEAM and out.slots.size() < MatchRules.TEAM_PLAYERS:
		out.slots.append(MatchSetup.slot_entry(out.slots.size(), MatchSetup.CONTROLLER_BOT, MatchSetup.INPUT_BOT))
	return out


## peer id -> slot index in setup()'s line-up, humans only.
static func slot_map(slots: Array[Dictionary]) -> Dictionary:
	var out := {}
	var index := 0
	for s: Dictionary in slots:
		var peer := int(s["peer"])
		if peer >= LobbyModel.HOST_ID:
			out[peer] = index
		if peer != LobbyModel.EMPTY:
			index += 1
	return out


## slot index in setup()'s line-up -> nickname, for humans that have one.
static func names(slots: Array[Dictionary]) -> Dictionary:
	var out := {}
	var map := slot_map(slots)
	for s: Dictionary in slots:
		if map.has(int(s["peer"])) and not String(s["name"]).is_empty():
			out[map[int(s["peer"])]] = String(s["name"])
	return out
