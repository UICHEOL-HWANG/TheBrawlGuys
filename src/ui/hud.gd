class_name Hud
extends CanvasLayer
## In-match HUD (design.md DS-LAY-02): damage counter + stocks per player along the top edge
## (1v1 at the far left and right, N players spread evenly; team 2v2 in two team frames, timed
## with the clock top-center and scores for stocks — HudSlots), result banner in the center, the
## local players' key hints along the bottom (DS-CMP-16, one bar per human in local 2-player).

signal restart_requested
signal menu_requested

const RESULT_BANNER_SCENE := preload("res://src/ui/components/result_banner/result_banner.tscn")
const LAYER := 5

var _margin: MarginContainer
var _row: HBoxContainer
var _banner: ResultBanner
var _slots: HudSlots
var _mode: Dictionary = {}
var _key_hints: KeyHintHud = null


## mode: the view's "mode" dictionary (combat-depth D): team frames, timer and scores per rule
## (HudSlots); {} = stock.
func setup(player_count: int, max_stocks: int, mode: Dictionary = {}) -> void:
	layer = LAYER
	if _row == null:
		_build_frame()
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_mode = mode
	_slots = HudSlots.build(_row, player_count, max_stocks, mode)
	hide_result()


func update_from(view: Dictionary) -> void:
	_slots.update_from(view)
	if _key_hints != null:
		_key_hints.update_gauges(view)


func show_result(winner_id: int, local_id: int) -> void:
	_banner.show_outcome(winner_id, local_id, _mode)


func hide_result() -> void:
	_banner.hide_result()


func set_menu_available(on: bool) -> void:
	_banner.set_menu_available(on)


func menu_button() -> UiMenuButton:
	return _banner.menu_button()


## Keyboard key bars at the bottom (DS-CMP-16), one per local player {prefix, slot, accent}
## (LocalPlayers.hint_players()); hidden while touch is active.
func show_key_hints(players: Array[Dictionary], touch_active: Callable) -> void:
	if _key_hints != null:
		return
	_key_hints = KeyHintHud.new()
	add_child(_key_hints)
	_key_hints.setup_players(players, touch_active, SettingsStore.new(),
			func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props))


func key_hints() -> KeyHintHud:
	return _key_hints


func counter_text(i: int) -> String:
	return _slots.counters[i].text()


func stocks_shown(i: int) -> int:
	return _slots.stocks[i].shown()


func slots() -> HudSlots:
	return _slots


func banner() -> ResultBanner:
	return _banner


func result_visible() -> bool:
	return _banner.visible


func _build_frame() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_safe_area()
	add_child(_margin)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_row)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_banner = RESULT_BANNER_SCENE.instantiate() as ResultBanner
	center.add_child(_banner)
	_banner.restart_requested.connect(func() -> void: restart_requested.emit())
	_banner.menu_requested.connect(func() -> void: menu_requested.emit())
	get_viewport().size_changed.connect(_apply_safe_area)


## Keeps the s5 margin inside the device safe area (DS-LAY-02, Phase 1 carry-over).
func _apply_safe_area() -> void:
	var vp := get_viewport().get_visible_rect()
	var safe := SafeArea.rect(get_viewport())
	_margin.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	_margin.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
	_margin.add_theme_constant_override("margin_top", int(safe.position.y - vp.position.y) + DS.S5)


func frame_margin(side: String) -> int:
	return _margin.get_theme_constant("margin_" + side)
