class_name FitCenter
extends ScrollContainer
## Centers one screen-level block (a card, a panel) and, when it is taller than the screen —
## phones after UI scaling (design.md DS-LAY-04) — lets it scroll vertically instead of running
## off the edges. Text is never shrunk to fit. Add the block to content().

var _center: CenterContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_center = CenterContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)


func content() -> CenterContainer:
	return _center
