class_name Hud
extends CanvasLayer
## In-match HUD (design.md DS-LAY-02 v2, combat-depth D): the HudStrip of PlayerCards — P1 + P3
## on the left, P2 + P4 on the right, the clock between them in timed matches — along the bottom
## edge (GetAmped-style layout), the result banner docked at the bottom (the strip steps aside for
## it, the winners cheer above it) and the local players' key hints
## (DS-CMP-16) along the top. While touch controls are shown they own the bottom of the screen
## (stick bottom-left, buttons bottom-right), so the strip moves to the top edge instead.

signal restart_requested
signal menu_requested

const RESULT_BANNER_SCENE := preload("res://src/ui/components/result_banner/result_banner.tscn")
const LAYER := 5

var _strip: HudStrip = null
var _banner: ResultBanner
var _dock: MarginContainer
var _mode: Dictionary = {}
var _key_hints: KeyHintHud = null
var _touch_active: Callable = func() -> bool: return false


## mode: the view's "mode" dictionary (rule, teams; {} = stock); characters[i]: slot i's
## CharacterData id; config: draws the portrait heads (null = shape badges only, tests).
func setup(player_count: int, max_stocks: int, mode: Dictionary = {}, characters: Array = [],
		config: GameConfig = null) -> void:
	layer = LAYER
	if _banner == null:
		_build_frame()
	if _strip != null:
		remove_child(_strip)
		_strip.queue_free()
	_mode = mode
	_strip = HudStrip.new()
	add_child(_strip)
	move_child(_strip, 0)
	_strip.build(player_count, max_stocks, mode, characters, config)
	_follow_touch()
	hide_result()


## view: the latest state view; events: every sim event since the last frame (combo badges;
## empty on frames without a sim tick, so no hit is counted twice).
func update_from(view: Dictionary, events: Array = []) -> void:
	if _strip == null:
		return
	_follow_touch()
	_strip.update_from(view, events)
	if _key_hints != null:
		_key_hints.update_gauges(view)


func show_result(winner_id: int, local_id: int) -> void:
	_banner.show_outcome(winner_id, local_id, _mode)
	if _strip != null:
		UiMotion.fade_out(_strip)


func hide_result() -> void:
	_banner.hide_result()
	if _strip != null:
		UiMotion.set_alpha(_strip, 1.0)
		_strip.visible = true


## Every card shows one marker and "∞" (the tutorial's practice arena never runs out of stocks).
func set_unlimited_stocks() -> void:
	if _strip == null:
		return
	for c: PlayerCard in _strip.cards:
		if c.stock_icons() != null:
			c.stock_icons().set_unlimited(true)


func set_menu_available(on: bool) -> void:
	_banner.set_menu_available(on)


func menu_button() -> UiMenuButton:
	return _banner.menu_button()


## A player's card shows their nickname (onboarding / the online lobby); "" or a bad slot changes nothing.
func show_name(slot: int, nick: String) -> void:
	if nick.is_empty() or _strip == null or slot < 0 or slot >= _strip.cards.size():
		return
	(_strip.cards[slot] as PlayerCard).set_player_name(nick)


## Keyboard key bars (DS-CMP-16), one per local player {prefix, slot, accent}
## (LocalPlayers.hint_players()); hidden while touch is active, which also moves the strip up.
func show_key_hints(players: Array[Dictionary], touch_active: Callable) -> void:
	if _key_hints != null:
		return
	_touch_active = touch_active
	_key_hints = KeyHintHud.new()
	add_child(_key_hints)
	_key_hints.setup_players(players, touch_active, SettingsStore.new(),
			func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props))
	_follow_touch()


func key_hints() -> KeyHintHud:
	return _key_hints


func strip() -> HudStrip:
	return _strip


func counter_text(i: int) -> String:
	return _strip.cards[i].text()


func stocks_shown(i: int) -> int:
	return _strip.cards[i].stocks_shown()


func banner() -> ResultBanner:
	return _banner


func result_visible() -> bool:
	return _banner.visible


## {top, bottom}: shares (0..1) of the screen height the strip (and, opposite it, the key hint
## bars) cover, so the camera frames the fight clear of them (HudSafeFrame).
func reserve() -> Dictionary:
	var height := get_viewport().get_visible_rect().size.y
	if _strip == null or height <= 0.0 or _strip.size.y <= 0.0:
		return {"top": 0.0, "bottom": 0.0}  # not laid out yet
	var r := _strip.get_global_rect()
	if _strip.is_edge_top():
		return {"top": r.end.y / height, "bottom": 0.0}
	return {"top": key_hints_bottom() / height, "bottom": (height - r.position.y) / height}


## Lowest edge of whatever the HUD shows along the top: the strip while touch moves it up (phones),
## else the key hint bars. Overlays (the tutorial card) start below it.
func top_bottom() -> float:
	if _strip != null and _strip.is_edge_top():
		return _strip.get_global_rect().end.y
	return key_hints_bottom()


## Lowest edge of the key hint bars on the top edge (0 when there are none). Hidden keys keep
## their room and the chip to show them again, so the bottom stays put (nothing covers the chip).
func key_hints_bottom() -> float:
	var bottom := 0.0
	if _key_hints != null:
		for b: KeyHintBar in _key_hints.bars():
			if b.is_visible_in_tree():
				bottom = maxf(bottom, (b.get_global_transform() * Rect2(Vector2.ZERO, b.size)).end.y)  # drawn size (KeyHintFit)
	return bottom


func frame_margin(side: String) -> int:
	return _strip.get_theme_constant("margin_" + side)


## Strip on top while touch controls are shown, key hints on the opposite edge.
func _follow_touch() -> void:
	var top := bool(_touch_active.call())
	if _strip != null and _strip.is_edge_top() != top:
		_strip.set_edge_top(top)
	if _key_hints != null:
		_key_hints.set_edge_top(not top)


func _build_frame() -> void:
	_dock = MarginContainer.new()
	_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)
	_banner = RESULT_BANNER_SCENE.instantiate() as ResultBanner
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.size_flags_vertical = Control.SIZE_SHRINK_END
	_dock.add_child(_banner)
	_dock_to_safe_area()
	_banner.restart_requested.connect(func() -> void: restart_requested.emit())
	_banner.menu_requested.connect(func() -> void: menu_requested.emit())
	get_viewport().size_changed.connect(func() -> void:
		_dock_to_safe_area()
		if _strip != null:
			_strip.apply_safe_area(get_viewport()))


## The banner sits one gap above the bottom of the safe area (home indicator, notches).
func _dock_to_safe_area() -> void:
	var vp := get_viewport().get_visible_rect()
	var safe := SafeArea.rect(get_viewport())
	_dock.add_theme_constant_override("margin_bottom", int(vp.end.y - safe.end.y) + DS.S5)
	_dock.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	_dock.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
