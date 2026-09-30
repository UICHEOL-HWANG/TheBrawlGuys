class_name ScreenRouter
extends Control
## The app shell's screen stack (platform B1, docs/design.md DS-LAY-03): login → title → match,
## later character → arena. Control screens live under the router (UI layer); other screens (the
## match scene) go under world_parent. Every change tracks screen_viewed. A curtain swap covers
## the screen with a cream fade (DS-TOK-05 slow) and runs on_swap before the new screen appears.

signal screen_shown(id: String, from_id: String)

var animate: bool = true
var world_parent: Node = null
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec

var _stack: Array[Dictionary] = []
var _curtain: ColorRect
var _busy: bool = false
var _shown_at_ms: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain = ColorRect.new()
	_curtain.color = DS.UI_SURFACE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP  # no clicks while screens swap
	_curtain.visible = false
	add_child(_curtain)


func push(id: String, node: Node, curtain: bool = false, on_swap: Callable = Callable()) -> void:
	_go(func() -> void:
		var from := current_id()
		_cover_top()
		_add(id, node, from), curtain, on_swap)


func replace(id: String, node: Node, curtain: bool = false, on_swap: Callable = Callable()) -> void:
	_go(func() -> void:
		var from := current_id()
		_drop_top()
		_add(id, node, from), curtain, on_swap)


func reset(id: String, node: Node, curtain: bool = false, on_swap: Callable = Callable()) -> void:
	_go(func() -> void:
		var from := current_id()
		while not _stack.is_empty():
			_drop_top()
		_add(id, node, from), curtain, on_swap)


func pop(curtain: bool = false, on_swap: Callable = Callable()) -> void:
	if _stack.size() < 2:
		push_warning("ScreenRouter: nothing to go back to")
		return
	_go(func() -> void:
		var from := current_id()
		_drop_top()
		_uncover_top()
		_shown(from), curtain, on_swap)


## Pops every screen above the (topmost) screen `id` (match → title across the select screens).
func pop_to(id: String, curtain: bool = false, on_swap: Callable = Callable()) -> void:
	var index := -1
	for i: int in _stack.size():
		if String(_stack[i]["id"]) == id:
			index = i
	if index < 0 or index == _stack.size() - 1:
		push_warning("ScreenRouter: no '%s' below the top to go back to" % id)
		return
	_go(func() -> void:
		var from := current_id()
		while _stack.size() > index + 1:
			_drop_top()
		_uncover_top()
		_shown(from), curtain, on_swap)


func current_id() -> String:
	return "" if _stack.is_empty() else String(_stack.back()["id"])


func current() -> Node:
	return null if _stack.is_empty() else _stack.back()["node"] as Node


func depth() -> int:
	return _stack.size()


func is_busy() -> bool:
	return _busy


func curtain() -> ColorRect:
	return _curtain


func _go(swap: Callable, curtain: bool, on_swap: Callable) -> void:
	var run := func() -> void:
		if on_swap.is_valid():
			on_swap.call()
		swap.call()
	if not (curtain and animate):
		run.call()
		return
	_busy = true
	_curtain.move_to_front()
	var tw := UiMotion.fade_in(_curtain, UiMotion.Token.SLOW)
	tw.tween_callback(run)
	tw.tween_callback(func() -> void:
		UiMotion.fade_out(_curtain).tween_callback(func() -> void: _busy = false))


func _add(id: String, node: Node, from: String) -> void:
	_stack.append({"id": id, "node": node})
	if node is Control:
		add_child(node)
		move_child(node, _curtain.get_index())
		if animate:
			UiMotion.fade_in(node as Control, UiMotion.Token.BASE)
	else:
		(world_parent if world_parent != null else self).add_child(node)
	_shown(from)


func _shown(from: String) -> void:
	var now := int(clock_ms.call())
	var dwell := now - _shown_at_ms if not from.is_empty() else 0
	_shown_at_ms = now
	track.call("screen_viewed", {"screen": current_id(), "from_screen": from, "dwell_ms_prev": dwell})
	screen_shown.emit(current_id(), from)


func _drop_top() -> void:
	var node := _stack.pop_back()["node"] as Node
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _cover_top() -> void:
	var top := current()
	if top is CanvasItem:
		(top as CanvasItem).visible = false


func _uncover_top() -> void:
	var top := current()
	if top is CanvasItem:
		(top as CanvasItem).visible = true
