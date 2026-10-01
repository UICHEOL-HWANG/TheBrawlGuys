class_name PlayerCard
extends PanelContainer
## One player in the match HUD strip (design.md DS-CMP-22, layout after the GetAmped reference
## docs/references/ref-getamped-hud.png — layout only, our own art): the portrait disc on the
## outer side (left cards: left, right cards: mirrored), "P1 바바리안" over a thick damage bar
## (CardBar DAMAGE, green -> red with the % on it) and a thin special gauge bar (flashes when
## full); stock pips (StockIcons) or, in timed matches, the score (ScoreBadge) beside the name.
## Team mode frames the card and tints the badges in the team color. A "N연타" combo badge pops
## over the portrait's top corner (set_combo). Dimmed while KO.

const KO_ALPHA := 0.4
const COMBO_POP := 1.3
const COMPACT_BAR := DS.CARD_WIDTH * 0.6
const STOCK_PIP := DS.S4

var _index: int = 0
var _bar: CardBar
var _gauge: CardBar
var _name: Label
var _stocks: StockIcons = null
var _score: ScoreBadge = null
var _portrait: PortraitBadge
var _combo: Label


## opts: mirrored (bool), tint (team Color or null), max_stocks (int), timed (bool), config
## (GameConfig, null = no 3D head), compact (bool).
func setup(index: int, character: String, opts: Dictionary) -> void:
	_index = index
	var tint: Variant = opts.get("tint")
	var ring: Color = tint if tint != null else PlayerStyle.color(index)
	add_theme_stylebox_override("panel", _frame(tint))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S3)
	add_child(row)
	_portrait = PortraitBadge.new()
	_portrait.setup(index, character, opts.get("config"), ring, opts.get("config") != null)
	_portrait.set_tint(tint)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)
	row.add_child(_bars(index, character, opts, tint))
	if bool(opts.get("mirrored", false)):
		row.move_child(_portrait, -1)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo = _combo_label()
	_portrait.add_child(_combo)
	set_compact(bool(opts.get("compact", false)))


func _bars(index: int, character: String, opts: Dictionary, tint: Variant) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", DS.S2)
	col.add_child(head)
	_name = Label.new()
	_name.text = "%s %s" % [PlayerStyle.label(index), CharacterCards.title_of(character)]
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_override("font", load(DS.FONT_BODY_PATH) as Font)
	_name.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	_name.add_theme_color_override("font_color", DS.UI_TEXT)
	head.add_child(_name)
	if bool(opts.get("timed", false)):
		_score = ScoreBadge.new()
		head.add_child(_score)
	else:
		_stocks = StockIcons.new()
		head.add_child(_stocks)
		_stocks.setup(index, int(opts.get("max_stocks", 0)), STOCK_PIP)
		_stocks.set_tint(tint)
	if bool(opts.get("mirrored", false)):
		head.move_child(_name, -1)
	_bar = CardBar.new(CardBar.Kind.DAMAGE)
	col.add_child(_bar)
	_gauge = CardBar.new(CardBar.Kind.GAUGE)
	col.add_child(_gauge)
	return col


## Phones and narrow windows: shorter bars so both groups and the clock fit one strip.
func set_compact(on: bool) -> void:
	for b: CardBar in [_bar, _gauge]:
		b.set_width(COMPACT_BAR if on else DS.CARD_WIDTH)


## f: the fighter's view (damage, stocks, state, special, gauge); score: timed points.
func update(f: Dictionary, score: int = 0) -> void:
	_bar.set_percent(float(f.get("damage", 0.0)))
	var has_special := not String(f.get("special", "")).is_empty()
	_gauge.set_gauge(float(f.get("gauge", 0.0)) / SpecialGauge.MAX if has_special else 0.0)
	if _stocks != null:
		_stocks.set_stocks(int(f.get("stocks", 0)))
	if _score != null:
		_score.set_score(score)
	modulate.a = KO_ALPHA if int(f.get("state", 0)) == Fighter.State.KO else 1.0


## Consecutive hits on one target (ComboTracker); under 2 hides the badge.
func set_combo(hits: int) -> void:
	var was := _combo.visible
	_combo.visible = hits >= 2
	if not _combo.visible:
		return
	var text := "%d연타" % hits
	if text != _combo.text or not was:
		_combo.text = text
		if is_inside_tree():
			UiMotion.bump(_combo, COMBO_POP)


func text() -> String:
	return _bar.text()


func stocks_shown() -> int:
	return _stocks.shown() if _stocks != null else 0


func score_text() -> String:
	return _score.text if _score != null else ""


func combo_text() -> String:
	return _combo.text if _combo.visible else ""


func gauge_bar() -> CardBar:
	return _gauge


func _frame(tint: Variant) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE_70
	sb.set_corner_radius_all(DS.RADIUS_M)
	sb.set_content_margin_all(DS.S1)
	sb.content_margin_left = DS.S2
	sb.content_margin_right = DS.S2
	if tint != null:
		sb.border_color = tint
		sb.set_border_width_all(DS.S1)
	return sb


func _combo_label() -> Label:
	var l := Label.new()
	l.visible = false
	l.position = Vector2(-DS.S3, -DS.S5)
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_BODY)
	l.add_theme_color_override("font_color", DS.PETAL_YELLOW)
	l.add_theme_color_override("font_outline_color", DS.FIRE)
	l.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 3)
	l.resized.connect(func() -> void: l.pivot_offset = l.size * 0.5)
	return l
