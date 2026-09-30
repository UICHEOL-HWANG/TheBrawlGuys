class_name KeyHintPreview
extends Node
## DS gallery preview of a KeyHintBar (DS-CMP-16): lights its caps one after another, each for
## STEP_S seconds, in the bar's accent. Added as a child of the bar by KeyHintBar.set_preview().

const STEP_S := 0.35

var _bar: KeyHintBar
var _s: float = 0.0
var _index: int = 0


func _init(bar: KeyHintBar) -> void:
	_bar = bar


func _ready() -> void:
	var ids := _bar.cap_ids()
	if not ids.is_empty():
		_bar.set_pressed(String(ids[0]), true)


func _process(delta: float) -> void:
	var ids := _bar.cap_ids()
	if ids.is_empty():
		return
	_s += delta
	if _s < STEP_S:
		return
	_s = 0.0
	_bar.set_pressed(String(ids[_index % ids.size()]), false)
	_index = (_index + 1) % ids.size()
	_bar.set_pressed(String(ids[_index]), true)
