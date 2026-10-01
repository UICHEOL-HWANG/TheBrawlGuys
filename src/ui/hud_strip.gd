class_name HudStrip
extends MarginContainer
## The match HUD strip (design.md DS-LAY-02 v2, combat-depth D; layout after the GetAmped
## reference docs/references/ref-getamped-hud.png, our own art): two groups of PlayerCards —
## left P1 + P3 (team 1), right P2 + P4 (team 2, cards mirrored so portraits face outward) — one
## card per row, and between them the MatchTimer in timed matches. Team mode heads each group
## with a "팀 1" / "팀 2" pill and frames the cards in the team color. It sits on the bottom edge,
## or on the top edge while touch controls own the bottom (set_edge_top); compact bars when the
## full strip is wider than the screen. Feeds a ComboTracker for the cards' "N연타" badges.

var cards: Array[PlayerCard] = []
var timer: MatchTimer = null
var headers: Array[Label] = []
var _row: HBoxContainer
var _combo := ComboTracker.new()
var _edge_top: bool = false
var _compact: bool = false
## Row width with full-size bars, measured once laid out (0 = not yet).
var _full_width: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## mode: the view's "mode" dictionary; characters[i]: slot i's CharacterData id; config: for the
## portrait heads (null = shape badges only).
func build(player_count: int, max_stocks: int, mode: Dictionary, characters: Array, config: GameConfig) -> void:
	var rule := String(mode.get("rule", MatchRules.STOCK))
	var teams: Array = mode.get("teams", []) if rule == MatchRules.TEAM else []
	var by_team := teams.size() == player_count
	var groups: Array[VBoxContainer] = [_group(), _group()]
	for side: int in 2:
		if by_team:
			groups[side].add_child(_header(side))
	cards.resize(player_count)
	for i: int in player_count:
		var side := int(teams[i]) if by_team else i % 2
		var card := PlayerCard.new()
		groups[side].add_child(card)
		card.setup(i, String(characters[i]) if i < characters.size() else CharacterData.DEFAULT, {
			"mirrored": side == 1, "tint": PlayerStyle.team_color(side) if by_team else null,
			"max_stocks": max_stocks, "timed": rule == MatchRules.TIMED, "config": config})
		cards[i] = card
	_row.add_child(groups[0])
	_row.add_child(_spacer())
	if rule == MatchRules.TIMED:
		timer = MatchTimer.new()
		timer.size_flags_vertical = Control.SIZE_SHRINK_END
		_row.add_child(timer)
		_row.add_child(_spacer())
	_row.add_child(groups[1])
	set_edge_top(_edge_top)
	resized.connect(_fit)


func _group() -> VBoxContainer:
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", DS.S1)
	g.alignment = BoxContainer.ALIGNMENT_END
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _header(team: int) -> Label:
	var l := Label.new()
	l.text = PlayerStyle.team_label(team)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_SURFACE)
	var pill := StyleBoxFlat.new()
	pill.bg_color = PlayerStyle.team_color(team)
	pill.set_corner_radius_all(DS.RADIUS_PILL)
	l.add_theme_stylebox_override("normal", pill)
	headers.append(l)
	return l


static func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Top edge (touch layouts: the stick and buttons own the bottom) or bottom edge (default).
func set_edge_top(on: bool) -> void:
	_edge_top = on
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if on else Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_END if on else Control.GROW_DIRECTION_BEGIN
	if is_inside_tree():
		apply_safe_area(get_viewport())


func is_edge_top() -> bool:
	return _edge_top


## s5 inside the device safe area on the sides and the strip's own edge.
func apply_safe_area(viewport: Viewport) -> void:
	var vp := viewport.get_visible_rect()
	var safe := SafeArea.rect(viewport)
	add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
	add_theme_constant_override("margin_top", int(safe.position.y - vp.position.y) + DS.S5 if _edge_top else 0)
	add_theme_constant_override("margin_bottom", 0 if _edge_top else int(vp.end.y - safe.end.y) + DS.S5)
	_fit()


## Compact bars when the full-size row is wider than the space inside the margins.
func _fit() -> void:
	if not is_inside_tree() or cards.is_empty():
		return
	if not _compact:
		_full_width = _row.get_combined_minimum_size().x
	var room := get_viewport().get_visible_rect().size.x - get_theme_constant("margin_left") \
			- get_theme_constant("margin_right")
	var compact := _full_width > room
	if compact != _compact:
		_compact = compact
		for c: PlayerCard in cards:
			c.set_compact(compact)


func is_compact() -> bool:
	return _compact


## Cards, clock and combo badges from a state view and the frame's sim events.
func update_from(view: Dictionary, events: Array) -> void:
	var mode: Dictionary = view.get("mode", {})
	var points: Array = mode.get("scores", [])
	var tick := int(view.get("tick", 0))
	_combo.on_events(events, tick)
	for f: Dictionary in view["fighters"]:
		var i := int(f["id"])
		if i < cards.size() and cards[i] != null:
			cards[i].update(f, int(points[i]) if i < points.size() else 0)
			cards[i].set_combo(_combo.count(i, tick))
	if timer != null:
		timer.set_ticks_left(int(mode.get("ticks_left", 0)), bool(mode.get("sudden_death", false)))
