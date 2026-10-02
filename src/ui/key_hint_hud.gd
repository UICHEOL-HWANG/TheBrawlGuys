class_name KeyHintHud
extends Control
## Places the KeyHintBars (design.md DS-CMP-16) on the HUD edge inside the s5 safe area (DS-LAY-02)
## and drives them: one bar per local player (alone centered; 2P: P1 left, P2 right, tagged, in
## player colors), caps follow InputMap every frame, the special cap rings on a full gauge, F2 or the
## chip hides / shows every bar ([hud] key_hints, tracked settings_changed). Too wide: compact, then
## shrink as a row (KeyHintFit). Everything steps aside while touch controls are active.

const BAR_SCENE := preload("res://src/ui/components/key_hint_bar/key_hint_bar.tscn")
const TOGGLE_ACTION := "hud_key_hints"
const SECTION := "hud"
const KEY := "key_hints"
const TRACK_KEY := "hud.key_hints"

var _margin: MarginContainer
var _edge_top: bool = false
## Safe-area pads in screen px {left, right, top, bottom} and the row's current fit scale.
var _pads: Dictionary = {}
var _fit_scale: float = 1.0
var _row: HBoxContainer
## One per player: {bar: KeyHintBar, caps: Array[Dictionary], slot: int}
var _entries: Array[Dictionary] = []
var _touch_active: Callable
var _store: SettingsStore
var _track: Callable


## One player (P1, slot 0). touch_active() -> bool: true while touch controls are on screen.
func setup(accent: Color, touch_active: Callable, store: SettingsStore, track: Callable) -> void:
	var one: Array[Dictionary] = [{"prefix": KeyHintSource.DEFAULT_PREFIX, "slot": 0, "accent": accent}]
	setup_players(one, touch_active, store, track)


## players: [{prefix, slot, accent}] in on-screen order (LocalPlayers.hint_players()).
func setup_players(players: Array[Dictionary], touch_active: Callable, store: SettingsStore,
		track: Callable) -> void:
	_touch_active = touch_active
	_store = store
	_track = track
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_frame()
	var shown := store.get_bool(SECTION, KEY, true)
	for i: int in players.size():
		if i > 0:
			_row.add_child(_spacer())
		_entries.append(_add_bar(players[i], players.size() > 1, i == players.size() - 1))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_apply_safe_area()
	for e: Dictionary in _entries:
		(e["bar"] as KeyHintBar).set_state(KeyHintBar.State.SHOWN if shown else KeyHintBar.State.HIDDEN, false)
	get_viewport().size_changed.connect(_apply_safe_area)
	_refresh()


## The match HUD strip sits at the bottom on desktop (DS-LAY-02 v2): the bars move to the top.
func set_edge_top(on: bool) -> void:
	if _margin == null or on == _edge_top:
		return
	_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if on else Control.PRESET_BOTTOM_WIDE)
	_margin.grow_vertical = Control.GROW_DIRECTION_END if on else Control.GROW_DIRECTION_BEGIN
	_edge_top = on
	_apply_safe_area()


func bar() -> KeyHintBar:
	return bars()[0]


func bars() -> Array[KeyHintBar]:
	var out: Array[KeyHintBar] = []
	for e: Dictionary in _entries:
		out.append(e["bar"] as KeyHintBar)
	return out


## Compact bars when the full-size ones need more than `width` (the row's width inside margins).
func fit_to(width: float) -> void:
	for b: KeyHintBar in bars():
		b.set_compact(false)
	var full := needed_width()
	if _entries.size() > 1 and full > width:
		_set_compact(true)
		if needed_width() > width:  # compact is not enough: shrink the full layout, gaps in proportion
			_set_compact(false)
	_fit_scale = KeyHintFit.scale_for(needed_width(), width)
	if _margin != null:
		KeyHintFit.apply(_margin, _pads, _fit_scale, _edge_top, get_viewport().get_visible_rect().size.x)


func _set_compact(on: bool) -> void:
	for b: KeyHintBar in bars():
		b.set_compact(on)


## 1 at full size, below 1 while the row is shrunk to fit (KeyHintFit).
func fit_scale() -> float:
	return _fit_scale


## Minimum width of the bars side by side (gaps included).
func needed_width() -> float:
	var total := 0.0
	for b: KeyHintBar in bars():
		total += b.get_combined_minimum_size().x
	var gaps := maxi(_row.get_child_count() - 1, 0)
	return total + gaps * _row.get_theme_constant("separation")


func is_shown() -> bool:
	return bar().state() == KeyHintBar.State.SHOWN


func toggle() -> void:
	var old := is_shown()
	for b: KeyHintBar in bars():
		b.set_state(KeyHintBar.State.HIDDEN if old else KeyHintBar.State.SHOWN)
	_store.set_value(SECTION, KEY, not old)
	_track.call("settings_changed", {"key": TRACK_KEY, "old": str(old), "new": str(not old)})


## Rings each player's special cap while their gauge is full (view fighters: special, gauge).
func update_gauges(view: Dictionary) -> void:
	for e: Dictionary in _entries:
		var ready := false
		for f: Dictionary in view.get("fighters", []):
			if int(f.get("id", -1)) == int(e["slot"]):
				ready = not String(f.get("special", "")).is_empty() \
						and float(f.get("gauge", 0.0)) >= SpecialGauge.MAX
		(e["bar"] as KeyHintBar).set_ready(KeyHintSource.SPECIAL_ID, ready)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _entries.is_empty():
		return
	visible = not bool(_touch_active.call())
	if not visible or not is_shown():
		return
	for e: Dictionary in _entries:
		var b := e["bar"] as KeyHintBar
		for c: Dictionary in e["caps"]:
			b.set_pressed(String(c["id"]), KeyHintSource.is_held(c["actions"]))


func _unhandled_input(event: InputEvent) -> void:
	if not _entries.is_empty() and visible and event.is_action_pressed(TOGGLE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func _build_frame() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", DS.S4)
	_margin.add_child(_row)


func _add_bar(player: Dictionary, tagged: bool, with_chip: bool) -> Dictionary:
	var b := BAR_SCENE.instantiate() as KeyHintBar
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	_row.add_child(b)
	var slot := int(player["slot"])
	var caps := KeyHintSource.caps(String(player["prefix"]))
	b.set_accent(player["accent"] as Color)
	if tagged:
		b.set_tag(PlayerStyle.label(slot))
	b.build(caps)
	b.set_chip_visible(with_chip)
	b.toggle_requested.connect(toggle)
	return {"bar": b, "caps": caps, "slot": slot}


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Bottom, left and right margins: s5 inside the device safe area (DS-LAY-02).
func _apply_safe_area() -> void:
	_pads = KeyHintFit.pads(get_viewport(), _edge_top)
	KeyHintFit.apply(_margin, _pads, _fit_scale, _edge_top, get_viewport().get_visible_rect().size.x)
	if not _entries.is_empty():
		_fit()


## Hidden bars keep their room (KeyHintBar), so they fit the same shown or hidden.
func _fit() -> void:
	fit_to(get_viewport().get_visible_rect().size.x - float(_pads["left"]) - float(_pads["right"]))
