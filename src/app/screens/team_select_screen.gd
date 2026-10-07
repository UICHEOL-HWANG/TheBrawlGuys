class_name TeamSelectScreen
extends OptionSelectScreen
## Team select (team 2v2, after the rule step, design.md DS-LAY-03 모드 → 경기 방식 → 팀 → 캐릭터
## → 경기장 → 대전): three splits — P1 with P2, P3 (the default, focused first) or P4 — each
## captioned with who is a human and who is a bot (TeamOptions), navigated like every
## OptionSelectScreen. Opens on the setup's current split. Tracks team_selected {pairing, teams,
## browse_count, focused} and select_cancelled {screen: "team", dwell_ms}.

signal teams_chosen(teams: Array[int])

const SCREEN := "team"
const TITLE_TEXT := "팀 나누기"

## Set before the screen enters the tree (its line-up names the humans and bots).
var setup: MatchSetup


func _screen_id() -> String:
	return SCREEN


func _title_text() -> String:
	return TITLE_TEXT


func _entries() -> Array[Dictionary]:
	return TeamOptions.entries(setup)


func _first_focus() -> int:
	return maxi(TeamOptions.IDS.find(TeamOptions.id_of(setup.team_split())), 0)


func _picked(id: String, browse_count: int, focused_ids: Array[String]) -> void:
	var teams := TeamOptions.teams_of(id)
	track.call("team_selected", {"pairing": id, "teams": teams.duplicate(), "browse_count": browse_count,
		"focused": focused_ids})
	teams_chosen.emit(teams)
