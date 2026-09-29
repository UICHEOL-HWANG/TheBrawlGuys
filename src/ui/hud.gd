class_name Hud
extends CanvasLayer
## In-match HUD (design.md DS-LAY-02): damage counter + stocks per player along the top edge
## (1v1 at the far left and right, N players spread evenly), result banner in the center.

signal restart_requested

const DAMAGE_COUNTER_SCENE := preload("res://src/ui/components/damage_counter/damage_counter.tscn")
const STOCK_ICONS_SCENE := preload("res://src/ui/components/stock_icons/stock_icons.tscn")
const RESULT_BANNER_SCENE := preload("res://src/ui/components/result_banner/result_banner.tscn")
const LAYER := 5

var _row: HBoxContainer
var _banner: ResultBanner
var _counters: Array[DamageCounter] = []
var _stocks: Array[StockIcons] = []


func setup(player_count: int, max_stocks: int) -> void:
	layer = LAYER
	if _row == null:
		_build_frame()
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_counters.clear()
	_stocks.clear()
	for i: int in player_count:
		if i > 0:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_row.add_child(spacer)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", DS.S2)
		_row.add_child(slot)
		var counter := DAMAGE_COUNTER_SCENE.instantiate() as DamageCounter
		slot.add_child(counter)
		counter.setup(i)
		var stocks := STOCK_ICONS_SCENE.instantiate() as StockIcons
		slot.add_child(stocks)
		stocks.setup(i, max_stocks)
		_counters.append(counter)
		_stocks.append(stocks)
	hide_result()


func update_from(view: Dictionary) -> void:
	for f: Dictionary in view["fighters"]:
		var i := int(f["id"])
		if i >= _counters.size():
			continue
		_counters[i].set_damage(float(f["damage"]))
		_counters[i].set_ko(int(f["state"]) == Fighter.State.KO)
		_stocks[i].set_stocks(int(f["stocks"]))


func show_result(winner_id: int, local_id: int) -> void:
	_banner.show_result(winner_id, local_id)


func hide_result() -> void:
	_banner.hide_result()


func counter_text(i: int) -> String:
	return _counters[i].text()


func stocks_shown(i: int) -> int:
	return _stocks[i].shown()


func result_visible() -> bool:
	return _banner.visible


func _build_frame() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, DS.S5)
	add_child(margin)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_row)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_banner = RESULT_BANNER_SCENE.instantiate() as ResultBanner
	center.add_child(_banner)
	_banner.restart_requested.connect(func() -> void: restart_requested.emit())
