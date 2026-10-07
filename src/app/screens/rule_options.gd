class_name RuleOptions
extends RefCounted
## What the rule select screen offers (combat-depth D, PRD §4.1 modes): one entry per MatchRules
## mode in display order, {rule, title, caption}. The timed caption reads the config's length.


static func entries(config: GameConfig) -> Array[Dictionary]:
	return [
		{"rule": MatchRules.STOCK, "title": "스톡", "caption": "목숨 %d개 · 끝까지 남으면 승리" % config.stocks},
		{"rule": MatchRules.TEAM, "title": "팀전 2:2", "caption": "두 팀 · 팀원은 다음에 고르기"},
		{"rule": MatchRules.TIMED, "title": "시간제", "caption": "%s · 링아웃 점수" % duration_text(config.timed_duration)},
	]


## "2분", "1분 30초", "45초".
static func duration_text(seconds: float) -> String:
	var total := roundi(seconds)
	var minutes := total / 60
	var rest := total % 60
	if minutes == 0:
		return "%d초" % rest
	return "%d분" % minutes if rest == 0 else "%d분 %d초" % [minutes, rest]
