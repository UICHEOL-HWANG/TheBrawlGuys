class_name TutorialSkipDialog
extends Control
## "튜토리얼을 건너뛸까요?" (Phase 5 T11, design.md DS-CMP-19): a full-screen `ui_shadow` scrim that
## takes every click and touch, with a centered Panel (DS-CMP-07) — title, a soft line saying where
## to replay it, and two MenuButtons: 계속하기 (secondary, focused, so a stray Enter keeps
## playing) and 건너뛰기 (primary). Esc (or the pad's Start) closes it like 계속하기.

signal resumed
signal confirmed

const TITLE := "튜토리얼을 건너뛸까요?"
const LINE := "타이틀의 '튜토리얼 다시 보기'로 언제든 다시 할 수 있어요."
const RESUME_TEXT := "계속하기"
const CONFIRM_TEXT := "건너뛰기"
const POP_FROM := 0.9

var _panel: UiPanel
var _resume: UiMenuButton
var _confirm: UiMenuButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = DS.UI_SHADOW
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = UiPanel.new()
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S4)
	_panel.add_child(col)
	col.add_child(TutorialCard.text_label(DS.FONT_DISPLAY_PATH, DS.SIZE_TITLE, DS.UI_TEXT))
	col.add_child(TutorialCard.text_label(DS.FONT_BODY_PATH, DS.SIZE_BODY, DS.UI_TEXT_SOFT))
	(col.get_child(0) as Label).text = TITLE
	(col.get_child(1) as Label).text = LINE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S4)
	col.add_child(row)
	_resume = _button(RESUME_TEXT, UiMenuButton.Kind.SECONDARY, resumed)
	_confirm = _button(CONFIRM_TEXT, UiMenuButton.Kind.PRIMARY, confirmed)
	row.add_child(_resume)
	row.add_child(_confirm)
	visible = false


func open() -> void:
	if visible:
		return
	visible = true
	_settle.call_deferred()


func close() -> void:
	visible = false
	if _resume.has_focus() or _confirm.has_focus():
		get_viewport().gui_release_focus()


## A frame later (layout done): pop in and focus 계속하기, unless it closed or left meanwhile.
func _settle() -> void:
	if is_inside_tree() and visible:
		UiMotion.pop_in(_panel, POP_FROM)
		_resume.grab_focus()


func is_open() -> bool:
	return visible


func resume_button() -> UiMenuButton:
	return _resume


func confirm_button() -> UiMenuButton:
	return _confirm


func _button(text: String, kind: UiMenuButton.Kind, sig: Signal) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = kind
	b.pressed.connect(func() -> void: sig.emit())
	return b
