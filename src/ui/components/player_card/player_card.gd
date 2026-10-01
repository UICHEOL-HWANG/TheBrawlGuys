class_name PlayerCard
extends HBoxContainer
## One player in the slim match HUD strip (design.md DS-CMP-22, layout after the GetAmped
## reference docs/references/ref-getamped-hud.png — layout only, our own art): a portrait disc on
## the outer side overlapping the card's edge (right cards mirrored), and a thin card with one line
## "P1 바바리안 ··· pips/score  42%" over a thick damage bar (CardBar DAMAGE, green -> red) and a
## thin special gauge bar (flashes when full). Team mode frames the card and tints the badges in
## the team color. The "N연타" burst (ComboBadge) sits on the card's inner top corner, away from
## the portrait. Dimmed while KO.

const KO_ALPHA := 0.4
const COMPACT_BAR := DS.CARD_WIDTH * 0.6
const STOCK_PIP := DS.S3
## From this damage % on, the % number takes the bar's ramp color (yellow and up).
const PCT_TINT_FROM := 50.0
## How far the portrait reaches over the card's outer edge.
const OVERLAP := DS.S4
## The combo burst sits just past the card's inner edge (mostly outside, clear of the % text).
const COMBO_OUT := DS.S3

var _index: int = 0
var _mirrored: bool = false
var _bar: CardBar
var _gauge: CardBar
var _name: Label
var _pct: Label
var _stocks: StockIcons = null
var _score: ScoreBadge = null
var _portrait: PortraitBadge
var _combo: ComboBadge


## opts: mirrored (bool), tint (team Color or null), max_stocks (int), timed (bool), config
## (GameConfig, null = no 3D head), compact (bool).
func setup(index: int, character: String, opts: Dictionary) -> void:
	_index = index
	_mirrored = bool(opts.get("mirrored", false))
	var tint: Variant = opts.get("tint")
	add_theme_constant_override("separation", -OVERLAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = PortraitBadge.new()
	_portrait.setup(index, character, opts.get("config"), tint if tint != null else PlayerStyle.color(index),
			opts.get("config") != null)
	_portrait.set_tint(tint)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.z_index = 1
	add_child(_portrait)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame(tint))
	panel.add_child(_bars(index, character, opts, tint))
	add_child(panel)
	if _mirrored:
		move_child(_portrait, -1)
	_combo = ComboBadge.new()
	_bar.add_child(_combo)
	_bar.resized.connect(_place_combo)
	set_compact(bool(opts.get("compact", false)))


func _bars(index: int, character: String, opts: Dictionary, tint: Variant) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S1 / 2)
	col.add_child(_line(index, character, opts, tint))
	_bar = CardBar.new(CardBar.Kind.DAMAGE)
	col.add_child(_bar)
	_gauge = CardBar.new(CardBar.Kind.GAUGE)
	col.add_child(_gauge)
	return col


## "P1 바바리안 ··· ●●● 42%" (mirrored: "42% ●●● ··· 바바리안 P1" order, name right-aligned).
func _line(index: int, character: String, opts: Dictionary, tint: Variant) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", DS.S2)
	_name = _text(DS.FONT_BODY_PATH, "%s %s" % [PlayerStyle.label(index), CharacterCards.title_of(character)])
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_name)
	if bool(opts.get("timed", false)):
		_score = ScoreBadge.new()
		_score.font_size = DS.SIZE_CAPTION
		line.add_child(_score)
	else:
		_stocks = StockIcons.new()
		_stocks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(_stocks)
		_stocks.setup(index, int(opts.get("max_stocks", 0)), STOCK_PIP)
		_stocks.set_tint(tint)
	_pct = _text(DS.FONT_DISPLAY_PATH, "0%")
	line.add_child(_pct)
	if _mirrored:
		for i: int in line.get_child_count():
			line.move_child(line.get_child(line.get_child_count() - 1), i)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return line


static func _text(font: String, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(font) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	return l


## Phones and narrow windows: shorter bars so both groups and the clock fit one strip.
func set_compact(on: bool) -> void:
	for b: CardBar in [_bar, _gauge]:
		b.set_width(COMPACT_BAR if on else DS.CARD_WIDTH)


## f: the fighter's view (damage, stocks, state, special, gauge); score: timed points.
func update(f: Dictionary, score: int = 0) -> void:
	var damage := float(f.get("damage", 0.0))
	_bar.set_percent(damage)
	_pct.text = "%d%%" % roundi(damage)
	_pct.add_theme_color_override("font_color", DamageColor.for_percent(damage, CardBar.DAMAGE_BAR_RAMP) \
			if damage >= PCT_TINT_FROM else DS.UI_TEXT)
	var has_special := not String(f.get("special", "")).is_empty()
	_gauge.set_gauge(float(f.get("gauge", 0.0)) / SpecialGauge.MAX if has_special else 0.0)
	if _stocks != null:
		_stocks.set_stocks(int(f.get("stocks", 0)))
	if _score != null:
		_score.set_score(score)
	modulate.a = KO_ALPHA if int(f.get("state", 0)) == Fighter.State.KO else 1.0


## Consecutive hits on one target (ComboTracker); under 2 hides the badge.
func set_combo(hits: int) -> void:
	_combo.set_hits(hits)
	_place_combo()


## The inner top corner: centred on the card's inner edge (away from the portrait) and its top.
func _place_combo() -> void:
	var out := COMBO_OUT + _combo.size.x * 0.4
	var edge_x: float = -out if _mirrored else _bar.size.x + out
	_combo.position = Vector2(edge_x, -_bar.position.y) - _combo.size * 0.5
	if is_inside_tree() and _combo.get_global_rect().position.y < 0.0:
		_combo.position.y = _bar.size.y + DS.S2 - _combo.size.y * 0.5  # strip on the top edge


func text() -> String:
	return _pct.text


func stocks_shown() -> int:
	return _stocks.shown() if _stocks != null else 0


func score_text() -> String:
	return _score.text if _score != null else ""


func combo_text() -> String:
	return _combo.text()


func gauge_bar() -> CardBar:
	return _gauge


func _frame(tint: Variant) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE_70
	sb.set_corner_radius_all(DS.RADIUS_S)
	sb.content_margin_top = 0
	sb.content_margin_bottom = DS.S1
	sb.content_margin_left = DS.S2 + (DS.S1 if _mirrored else OVERLAP)
	sb.content_margin_right = DS.S2 + (OVERLAP if _mirrored else DS.S1)
	if tint != null:
		sb.border_color = tint
		sb.set_border_width_all(DS.S1 / 2)
	return sb
