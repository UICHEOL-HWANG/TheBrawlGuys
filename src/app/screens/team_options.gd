class_name TeamOptions
extends RefCounted
## What the team select offers (team 2v2): who plays with P1 — P2, P3 or P4 — so both teams
## always have two fighters. One entry per split in display order, {id, title, caption}: the id
## names P1's team ("13" = P1 and P3, the default MatchRules split), the title both teams
## ("P1·P3 대 P2·P4") and the caption who is a human and who is a bot ("나 + 봇 대 봇 + 봇"; with
## two or more humans they are named P1, P2, ...).

const IDS: Array[String] = ["12", "13", "14"]
const DEFAULT_ID := "13"
const ME_TEXT := "나"
const BOT_TEXT := "봇"


static func entries(setup: MatchSetup) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in IDS:
		var teams := teams_of(id)
		out.append({"id": id, "title": _sides(teams, func(slot: int) -> String: return "P%d" % (slot + 1), "·"),
			"caption": _sides(teams, _name.bind(setup), " + "), "teams": teams})
	return out


## The team per slot for a split id: P1 and the partner are team 0, the other two team 1.
static func teams_of(id: String) -> Array[int]:
	var partner := int(id.substr(1)) - 1
	var out: Array[int] = []
	for slot: int in MatchRules.TEAM_PLAYERS:
		out.append(0 if slot == 0 or slot == partner else 1)
	return out


## The split id of a team per slot ("" when it is none of IDS).
static func id_of(teams: Array[int]) -> String:
	for id: String in IDS:
		if teams_of(id) == teams:
			return id
	return ""


## "<team 0> 대 <team 1>", each team's slots named by name_of and joined by sep.
static func _sides(teams: Array[int], name_of: Callable, sep: String) -> String:
	var sides: Array[String] = []
	for team: int in MatchRules.TEAM_COUNT:
		var names: PackedStringArray = []
		for slot: int in teams.size():
			if teams[slot] == team:
				names.append(String(name_of.call(slot)))
		sides.append(sep.join(names))
	return " 대 ".join(sides)


static func _name(slot: int, setup: MatchSetup) -> String:
	if slot >= setup.slots.size() or setup.slots[slot]["controller"] == MatchSetup.CONTROLLER_BOT:
		return BOT_TEXT
	var humans := setup.player_count() - setup.bot_slots().size()
	return ME_TEXT if humans == 1 else "P%d" % (slot + 1)
