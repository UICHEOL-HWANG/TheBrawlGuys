class_name QuickMatchPrefs
extends RefCounted
## Device-local bot match preferences. Never restores controllers, peers or old seeds.
var _store: SettingsStore
var _saved: Dictionary = {}


func _init(store: SettingsStore = null) -> void:
	_store = store
	if _store != null:
		var raw: Variant = _store.get_value("quick_match", "selection", {})
		if raw is Dictionary:
			_saved = raw.duplicate(true)


static func create_default() -> QuickMatchPrefs:
	return QuickMatchPrefs.new(null if DisplayServer.get_name() == "headless" else SettingsStore.new())


func remember(setup: MatchSetup) -> void:
	if setup.mode != MatchSetup.MODE_BOT or setup.local_slots() != [0] or not setup.validate().is_empty():
		return
	_saved = {"rule": setup.rule, "arena": setup.arena_id, "character": setup.characters()[0],
		"teams": setup.teams.duplicate()}
	if _store != null:
		_store.set_value("quick_match", "selection", _saved)


func build(seed: int) -> MatchSetup:
	var setup := MatchSetup.vs_bots(2, seed)
	setup.set_rule(_choice("rule", MatchRules.MODES, MatchRules.STOCK))
	setup.arena_id = _choice("arena", ArenaCatalog.ids(), ArenaCatalog.STAGE_IDS[0])
	var character := _choice("character", CharacterData.IDS, CharacterData.BARBARIAN)
	var raw: Variant = _saved.get("teams", [])
	if setup.rule == MatchRules.TEAM and raw is Array and raw.size() == 4:
		var valid := true
		for team: Variant in raw:
			valid = valid and typeof(team) == TYPE_INT and team in [0, 1]
		if valid:
			var teams: Array[int] = []
			teams.assign(raw)
			if MatchRules.is_two_vs_two(teams):
				setup.set_teams(teams)
	setup.assign_characters({0: character})
	return setup


func _choice(key: String, allowed: Array, fallback: String) -> String:
	var value: Variant = _saved.get(key)
	return value if value is String and allowed.has(value) else fallback


## Lobby pick changes only the character, preserving the remembered match settings.
func choose_character(character: String) -> void:
	if not CharacterData.IDS.has(character):
		return
	_saved["character"] = character
	if _store != null:
		_store.set_value("quick_match", "selection", _saved)
