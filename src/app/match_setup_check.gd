class_name MatchSetupCheck
extends RefCounted
## MatchSetup.validate, split out of MatchSetup: one message per reason the setup cannot start a
## match (no slots, unknown rule / arena / controller / character, a team rule without four
## fighters, chosen teams that are not two vs two or outside the team rule).


static func errors(setup: MatchSetup) -> PackedStringArray:
	var out := PackedStringArray()
	if setup.slots.is_empty():
		out.append("no slots")
	if not MatchRules.MODES.has(setup.rule):
		out.append("unknown rule '%s'" % setup.rule)
	elif setup.rule == MatchRules.TEAM and setup.slots.size() != MatchRules.TEAM_PLAYERS:
		out.append("team rule needs %d slots" % MatchRules.TEAM_PLAYERS)
	if not setup.teams.is_empty():
		out.append_array(_team_errors(setup))
	if not ArenaCatalog.ids().has(setup.arena_id):
		out.append("unknown arena '%s'" % setup.arena_id)
	for i: int in setup.slots.size():
		out.append_array(_slot_errors(i, setup.slots[i]))
	return out


static func _team_errors(setup: MatchSetup) -> PackedStringArray:
	var out := PackedStringArray()
	if setup.rule != MatchRules.TEAM:
		out.append("teams %s only belong to the team rule" % str(setup.teams))
	elif not MatchRules.is_two_vs_two(setup.teams):
		out.append("teams %s must be two vs two" % str(setup.teams))
	return out


static func _slot_errors(i: int, s: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if int(s.get("slot", -1)) != i:
		out.append("slot %d: slot index must be %d" % [i, i])
	if not MatchSetup.CONTROLLERS.has(String(s.get("controller", ""))):
		out.append("slot %d: unknown controller '%s'" % [i, s.get("controller", "")])
	var character := String(s.get("character", CharacterData.DEFAULT))
	if character != CharacterData.DEFAULT and not CharacterData.IDS.has(character):
		out.append("slot %d: unknown character '%s'" % [i, character])
	return out
