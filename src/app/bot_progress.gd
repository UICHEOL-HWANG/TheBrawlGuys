class_name BotProgress
extends RefCounted
## Device-local bot completion history; independent of matchmaking / DDA skill.
const COMPLETION_XP := 20
const WIN_XP := 10
const LEVEL_XP := 100
const RECENT_LIMIT := 5
const DEDUP_LIMIT := 64
var _store: SettingsStore
var _data: Dictionary = {}

func _init(store: SettingsStore = null) -> void:
	_store = store
	if store != null:
		var raw: Variant = store.get_value("bot_progress", "history", {})
		if raw is Dictionary:
			_data = raw.duplicate(true)

static func create_default() -> BotProgress:
	return BotProgress.new(SettingsStore.new() if PlatformEnv.is_live() else null)

func summary(character: String) -> Dictionary:
	var raw: Variant = _data.get(character, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	var played := _count(row.get("played", 0))
	var wins := mini(_count(row.get("wins", 0)), played)
	var draws := mini(_count(row.get("draws", 0)), played - wins)
	var xp := played * COMPLETION_XP + wins * WIN_XP
	return {"played": played, "wins": wins, "draws": draws, "losses": played - wins - draws,
		"ringouts": _count(row.get("ringouts", 0)), "special_hits": _count(row.get("special_hits", 0)),
		"xp": xp, "level": 1 + floori(float(xp) / LEVEL_XP), "within": xp % LEVEL_XP}

func recent() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = _data.get("recent", [])
	if raw is Array:
		for item: Variant in raw:
			if item is String and item in ["승", "패", "무"] and out.size() < RECENT_LIMIT:
				out.append(item)
	return out

func record(setup: MatchSetup, final: Dictionary, match_id: String, players: Array[Dictionary] = []) -> String:
	if setup.mode != MatchSetup.MODE_BOT or setup.local_slots() != [0] \
			or not setup.validate().is_empty() or not bool(final.get("match_over", false)) or match_id.is_empty():
		return ""
	var character := setup.characters()[0]
	if not CharacterData.IDS.has(character):
		return ""
	var raw_ids: Variant = _data.get("ids", [])
	var ids: Array = raw_ids.duplicate() if raw_ids is Array else []
	if ids.has(match_id):
		return ""
	var winner := int(final.get("winner", Rules.DRAW))
	var draw := winner == Rules.DRAW
	var won := winner == 0
	if setup.rule == MatchRules.TEAM and not draw:
		var split := setup.team_split()
		won = winner >= 0 and winner < split.size() and split[winner] == split[0]
	var row := summary(character)
	var before := int(row["level"])
	var previous := row.duplicate()
	for player: Dictionary in players:
		if player.get("slot", -1) == 0:
			row["ringouts"] += _count(player.get("ringouts_scored", 0))
			row["special_hits"] += _count(player.get("special_hits", 0))
			break
	row["played"] += 1
	row["wins"] += int(won and not draw)
	row["draws"] += int(draw)
	_data[character] = row
	var history := recent()
	history.push_front("무" if draw else ("승" if won else "패"))
	history.resize(mini(history.size(), RECENT_LIMIT))
	_data["recent"] = history
	ids.append(match_id)
	while ids.size() > DEDUP_LIMIT:
		ids.pop_front()
	_data["ids"] = ids
	if _store != null:
		_store.set_value("bot_progress", "history", _data)
	var level := int(summary(character)["level"])
	var reward := COMPLETION_XP + (WIN_XP if won and not draw else 0)
	var message := "숙련도 +%d XP · %sLv.%d" % [reward, "레벨 업! " if level > before else "", level]
	var unlocked := CharacterChallenges.newly_completed(previous, summary(character))
	if not unlocked.is_empty():
		message += "\n도전 달성 · " + " · ".join(unlocked)
	return message

static func _count(value: Variant) -> int:
	return clampi(value, 0, 1000000) if typeof(value) == TYPE_INT else 0
