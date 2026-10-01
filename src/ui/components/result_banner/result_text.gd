class_name ResultText
extends RefCounted
## Result banner wording (design.md DS-CMP-09, combat-depth D) from the winner, the local viewer
## (ResultBanner.NO_LOCAL when nobody's point of view applies) and the view's "mode" dictionary:
## {title, detail}. Stock: "승리!" / "패배…" / "무승부" / "P2 승리!", no detail. Team: the local
## player's team decides win or loss ("팀 1 승리!" with no single viewer), detail = the winning
## team and its players. Timed: like stock, detail = every score, highest first.

const NO_LOCAL := -1


static func of(winner_id: int, local_id: int, mode: Dictionary) -> Dictionary:
	var rule := String(mode.get("rule", MatchRules.STOCK))
	if winner_id == Rules.DRAW:
		return {"title": "무승부", "detail": _scores(mode) if rule == MatchRules.TIMED else ""}
	if rule == MatchRules.TEAM:
		return _team(winner_id, local_id, mode)
	var title := _title(winner_id == local_id, local_id, PlayerStyle.label(winner_id))
	return {"title": title, "detail": _scores(mode) if rule == MatchRules.TIMED else ""}


static func _title(won: bool, local_id: int, winner_name: String) -> String:
	if local_id == NO_LOCAL:
		return "%s 승리!" % winner_name
	return "승리!" if won else "패배…"


static func _team(winner_id: int, local_id: int, mode: Dictionary) -> Dictionary:
	var teams: Array = mode.get("teams", [])
	var team := int(mode.get("winner_team", -1))
	if team < 0 and winner_id >= 0 and winner_id < teams.size():
		team = int(teams[winner_id])
	var members: Array[String] = []
	for i: int in teams.size():
		if int(teams[i]) == team:
			members.append(PlayerStyle.label(i))
	var won := local_id >= 0 and local_id < teams.size() and int(teams[local_id]) == team
	var team_name := PlayerStyle.team_label(team)
	return {"title": _title(won, local_id, team_name),
		"detail": "%s 승리 · %s" % [team_name, " · ".join(members)]}


## "P3 4점 · P1 2점 · P2 0점 · P4 -1점".
static func _scores(mode: Dictionary) -> String:
	var points: Array = mode.get("scores", [])
	var order: Array = range(points.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return int(points[a]) > int(points[b]) or (int(points[a]) == int(points[b]) and a < b))
	var parts: Array[String] = []
	for i: int in order:
		parts.append("%s %d점" % [PlayerStyle.label(i), int(points[i])])
	return " · ".join(parts)
