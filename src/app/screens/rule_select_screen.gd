class_name RuleSelectScreen
extends OptionSelectScreen
## Rule select (combat-depth D, PRD §4.1 modes, design.md DS-LAY-03 모드 → 경기 방식 → (팀) →
## 캐릭터 → 경기장 → 대전): three options — 스톡 / 팀전 2:2 / 시간제 — each with a one-line
## caption (RuleOptions), navigated like every OptionSelectScreen. Tracks rule_selected {rule,
## browse_count, focused} (focused: the distinct rules that had the focus, in order, the default
## first — candidates vs the pick) and select_cancelled {screen, dwell_ms}.

signal rule_chosen(rule: String)

const SCREEN := "rule"
const TITLE_TEXT := "경기 방식"

## The app's GameConfig (stock count and timed length in the captions); null loads the default.
var config: GameConfig = null


func rule_ids() -> Array[String]:
	return option_ids()


func _screen_id() -> String:
	return SCREEN


func _title_text() -> String:
	return TITLE_TEXT


func _entries() -> Array[Dictionary]:
	var cfg := config if config != null else load(MenuBackdrop.CONFIG_PATH) as GameConfig
	var out: Array[Dictionary] = []
	for e: Dictionary in RuleOptions.entries(cfg):
		out.append(e.merged({"id": e["rule"]}))
	return out


func _picked(id: String, browse_count: int, focused_ids: Array[String]) -> void:
	track.call("rule_selected", {"rule": id, "browse_count": browse_count, "focused": focused_ids})
	rule_chosen.emit(id)
