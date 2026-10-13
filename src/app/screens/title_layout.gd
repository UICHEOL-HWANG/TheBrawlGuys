class_name TitleLayout
extends RefCounted
## Node building for the title screen (design.md DS-LAY-03): spacer gaps, the greeting row, the
## small corner buttons and the quick-start summary (DS-CMP-23 lobby picks). Containers and DS
## tokens only, so the screen follows UI scaling on phones.

const RULE_NAMES := {"stock": "스톡", "team": "2대2", "timed": "시간제"}
const DEFAULT_ARENA_TEXT := "기본 경기장"
const FIRST_MATCH_TEXT := "첫 봇전에서 숙련도를 쌓아보세요"
const RECENT_PREFIX := "최근 봇전 · "


static func gap(height: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = height
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## The greeting label with its nickname link beside it, centered on one line.
static func greeting_row(greeting: Label, link: LinkButton) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(greeting)
	row.add_child(link)
	return row


## A small secondary button tucked into root's top-right (or top-left) corner.
static func corner_button(root: Control, label: String, right: bool) -> UiMenuButton:
	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	corner.add_theme_constant_override("margin_top", DS.S5)
	corner.add_theme_constant_override("margin_right" if right else "margin_left", DS.S5)
	root.add_child(corner)
	var b := secondary_button(label)
	corner.add_child(b)
	b.custom_minimum_size = Vector2(0, DS.S8)
	return b


static func secondary_button(text: String) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = UiMenuButton.Kind.SECONDARY
	return b


## "기사 · 스톡\n<arena>\n최근 봇전 · …": the quick-start setup and the recent bot matches.
static func quick_summary(setup: MatchSetup, progress: BotProgress) -> String:
	var rule: String = RULE_NAMES.get(setup.rule, setup.rule)
	var arena := String(ArenaCards.NAMES.get(setup.arena_id, [DEFAULT_ARENA_TEXT])[0])
	var history := progress.recent()
	var recent_text := FIRST_MATCH_TEXT if history.is_empty() else RECENT_PREFIX + "  ".join(history)
	return "%s · %s\n%s\n%s" % [CharacterCards.title_of(setup.characters()[0]), rule, arena, recent_text]
