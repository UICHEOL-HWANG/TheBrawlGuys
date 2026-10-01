class_name HudSlots
extends RefCounted
## The HUD's top row for one match rule (design.md DS-LAY-02, combat-depth D), split out of Hud.
## Each player slot is a DamageCounter over StockIcons (stock, team) or a ScoreBadge (timed).
## stock: slots spread evenly in slot order. timed: the same with the MatchTimer in the middle.
## team: two TeamFrames — team 1 (P1 + P3) at the left edge, team 2 (P2 + P4) at the right —
## with every badge in the team color; the P shapes keep each player apart.

const DAMAGE_COUNTER_SCENE := preload("res://src/ui/components/damage_counter/damage_counter.tscn")
const STOCK_ICONS_SCENE := preload("res://src/ui/components/stock_icons/stock_icons.tscn")

var counters: Array[DamageCounter] = []
## Per slot; null entries in timed matches.
var stocks: Array[StockIcons] = []
## Per slot; null entries outside timed matches.
var scores: Array[ScoreBadge] = []
var timer: MatchTimer = null
var frames: Array[TeamFrame] = []
var _max_stocks: int = 0
var _timed: bool = false
var _teams: Array = []


## Fills row (already in the tree) for player_count players under the view's "mode" dictionary.
static func build(row: HBoxContainer, player_count: int, max_stocks: int, mode: Dictionary) -> HudSlots:
	var s := HudSlots.new()
	var rule := String(mode.get("rule", MatchRules.STOCK))
	s._max_stocks = max_stocks
	s._timed = rule == MatchRules.TIMED
	var teams: Array = mode.get("teams", [])
	s.counters.resize(player_count)
	s.stocks.resize(player_count)
	s.scores.resize(player_count)
	if rule == MatchRules.TEAM and teams.size() == player_count:
		s._teams = teams
		s._build_teams(row, player_count)
	else:
		s._build_spread(row, player_count)
	return s


func _build_spread(row: HBoxContainer, player_count: int) -> void:
	var middle := ceili(player_count / 2.0)
	for i: int in player_count:
		if _timed and i == middle:
			row.add_child(_spacer())
			timer = MatchTimer.new()
			row.add_child(timer)
		if i > 0:
			row.add_child(_spacer())
		_add_slot(row, i)


func _build_teams(row: HBoxContainer, player_count: int) -> void:
	for team: int in MatchRules.TEAM_COUNT:
		if team > 0:
			row.add_child(_spacer())
		var frame := TeamFrame.new()
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
		frame.setup(team)
		frames.append(frame)
		for i: int in player_count:
			if int(_teams[i]) == team:
				_add_slot(frame.slots(), i)


## One player's box: DamageCounter over StockIcons or a ScoreBadge, tinted in team mode.
func _add_slot(parent: Container, i: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", DS.S2)
	parent.add_child(box)
	var tint: Variant = PlayerStyle.team_color(int(_teams[i])) if i < _teams.size() else null
	var counter := DAMAGE_COUNTER_SCENE.instantiate() as DamageCounter
	box.add_child(counter)
	counter.setup(i)
	counter.set_tint(tint)
	counters[i] = counter
	if _timed:
		var badge := ScoreBadge.new()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(badge)
		scores[i] = badge
		return
	var icons := STOCK_ICONS_SCENE.instantiate() as StockIcons
	box.add_child(icons)
	icons.setup(i, _max_stocks)
	icons.set_tint(tint)
	stocks[i] = icons


static func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Damage, KO dimming, stocks or scores and the clock from a state view.
func update_from(view: Dictionary) -> void:
	var mode: Dictionary = view.get("mode", {})
	var points: Array = mode.get("scores", [])
	for f: Dictionary in view["fighters"]:
		var i := int(f["id"])
		if i >= counters.size() or counters[i] == null:
			continue
		counters[i].set_damage(float(f["damage"]))
		counters[i].set_ko(int(f["state"]) == Fighter.State.KO)
		if stocks[i] != null:
			stocks[i].set_stocks(int(f["stocks"]))
		if scores[i] != null and i < points.size():
			scores[i].set_score(int(points[i]))
	if timer != null:
		timer.set_ticks_left(int(mode.get("ticks_left", 0)), bool(mode.get("sudden_death", false)))
