class_name ScreenFlash
extends CanvasLayer
## Heavy-hit screen flash (design.md DS-VFX-01 v2): a faint warm glow over the whole screen that
## fades out in DURATION. Low alpha on purpose (photosensitivity); input passes through.

const DURATION := 0.12

var _rect: ColorRect
var _left: float = 0.0


func _init() -> void:
	_rect = ColorRect.new()
	_rect.color = DS.SCREEN_FLASH
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


func flash() -> void:
	_left = DURATION
	_rect.visible = true
	_rect.modulate.a = 1.0


func stop() -> void:
	_rect.visible = false


func showing() -> bool:
	return _rect.visible


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _rect.visible:
		return
	_left -= delta
	if _left <= 0.0:
		_rect.visible = false
		return
	_rect.modulate.a = _left / DURATION
