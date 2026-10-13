class_name CharacterChallenges
extends RefCounted
## Permanent bot-match milestones, derived from each character's saved totals.
const GOALS := [
	{"key": "wins", "target": 1, "title": "첫 승리", "action": "봇전 승리"},
	{"key": "ringouts", "target": 10, "title": "밀어내기 달인", "action": "링아웃"},
	{"key": "special_hits", "target": 20, "title": "필살기 전문가", "action": "필살기 적중"},
]

static func completed(stats: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for goal: Dictionary in GOALS:
		if int(stats.get(goal["key"], 0)) >= int(goal["target"]):
			out.append(String(goal["title"]))
	return out

static func next_text(stats: Dictionary) -> String:
	var done := completed(stats)
	for goal: Dictionary in GOALS:
		if not done.has(String(goal["title"])):
			return "도전 %d/%d · %s\n%s %d/%d" % [done.size(), GOALS.size(), goal["title"],
				goal["action"], int(stats.get(goal["key"], 0)), goal["target"]]
	return "도전 %d/%d · 모두 달성!\n이 캐릭터의 도전을 완수했어요" % [done.size(), GOALS.size()]

static func newly_completed(before: Dictionary, after: Dictionary) -> Array[String]:
	var previous := completed(before)
	var out: Array[String] = []
	for title: String in completed(after):
		if not previous.has(title):
			out.append(title)
	return out
