class_name SettingsScreen
extends Control
## Settings (design.md DS-LAY-03, laid out like the online menu): one Panel with a sound and a
## music volume slider (UserVolume, applied to the buses as you drag), a reduce-motion switch
## (the special cut-in keeps the camera still) and a bot-difficulty switch (DdaSetting: bots
## follow your skill, read at match start). Every change is saved at once in SettingsStore.
## Esc / pad B / 뒤로 go back.

signal cancelled

const TITLE_TEXT := "설정"
const SFX_TEXT := "효과음"
const MUSIC_TEXT := "음악"
const MOTION_TEXT := "모션 줄이기"
const MOTION_HINT := "필살기 컷인에서 카메라 고정"
const DDA_TEXT := "봇 난이도 자동 조절"
const DDA_HINT := "내 실력에 맞춰 봇이 강해지거나 약해짐"
const BACK_TEXT := "뒤로"
const HINT_TEXT := "Esc 뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)
const ROWS := [[UserVolume.SFX, SFX_TEXT], [UserVolume.MUSIC, MUSIC_TEXT]]

## Set before the screen enters the tree.
var store: SettingsStore
var config: GameConfig
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
## The A/B bucket key (DdaSetting.device_key when empty).
var device_key: String = ""

var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _motion: CheckButton
var _dda: CheckButton
var _dragging: bool = false
var _left: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if store == null:
		store = SettingsStore.new()
	if config == null:
		config = GameConfig.new()
	var back_button := ArenaSelectLayout.back_button(BACK_TEXT)
	back_button.pressed.connect(back)
	var footer := ArenaSelectLayout.build(self, TITLE_TEXT, _panel(), back_button,
			ArenaSelectLayout.hint_label(HINT_TEXT))
	ArenaSelectLayout.apply_safe_area(footer, get_viewport())
	(_sliders[UserVolume.SFX] as Control).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).pressed
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		back()
		get_viewport().set_input_as_handled()


func back() -> void:
	if _left:
		return  # a second Esc / tap before the router has popped us
	_left = true
	cancelled.emit()


func slider(key: String) -> HSlider:
	return _sliders[key] as HSlider


func value_text(key: String) -> String:
	return (_values[key] as Label).text


func motion_toggle() -> CheckButton:
	return _motion


func dda_toggle() -> CheckButton:
	return _dda


## Settings keep the backdrop fight low, like the online menu.
func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


## Two columns so the panel stays clear of the title and footer on short screens: the volume
## sliders, then the switches; ↓ from the last slider and ↑ from the first switch cross over.
func _panel() -> UiPanel:
	var panel := UiPanel.new()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", DS.S7)
	panel.add_child(columns)
	var sound := SettingsRows.column()
	var play := SettingsRows.column()
	columns.add_child(sound)
	columns.add_child(play)
	for r: Array in ROWS:
		sound.add_child(_volume_row(String(r[0]), String(r[1])))
	_motion = CheckButton.new()
	_motion.button_pressed = store.get_bool(SpecialCutInDirector.SETTINGS_SECTION,
			SpecialCutInDirector.SETTINGS_KEY, false)
	_motion.toggled.connect(_on_motion)
	play.add_child(SettingsRows.toggle_row(MOTION_TEXT, MOTION_HINT, _motion))
	_dda = CheckButton.new()
	_dda.button_pressed = DdaSetting.is_on(store, config, device_key if device_key != "" else DdaSetting.device_key())
	_dda.disabled = config.dda_enabled == 0
	_dda.toggled.connect(_on_dda)
	play.add_child(SettingsRows.toggle_row(DDA_TEXT, DDA_HINT, _dda))
	SettingsRows.link_down(slider(UserVolume.MUSIC), _motion)
	return panel


func _volume_row(key: String, name: String) -> Control:
	var out := {}
	var row := SettingsRows.slider_row(name, out)
	var s := out["slider"] as HSlider
	_sliders[key] = s
	_values[key] = out["value"]
	s.value = UserVolume.percent(store, key)
	_show_percent(key)
	s.value_changed.connect(_on_volume.bind(key))
	s.drag_started.connect(func() -> void: _dragging = true)
	s.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		_save(key))
	return row


## The buses follow the handle at once; the file is written when the drag ends (or at once for
## a key / pad step), not on every tick of a drag.
func _on_volume(_value: float, key: String) -> void:
	_show_percent(key)
	AudioBuses.apply(config, _percent(UserVolume.SFX), _percent(UserVolume.MUSIC))
	if not _dragging:
		_save(key)


func _percent(key: String) -> int:
	return int(slider(key).value)


func _save(key: String) -> void:
	UserVolume.set_percent(store, key, _percent(key))


func _show_percent(key: String) -> void:
	(_values[key] as Label).text = "%d%%" % int(slider(key).value)


func _on_motion(on: bool) -> void:
	store.set_value(SpecialCutInDirector.SETTINGS_SECTION, SpecialCutInDirector.SETTINGS_KEY, on)


func _on_dda(on: bool) -> void:
	DdaSetting.save(store, on)
	track.call("settings_changed", {"key": DdaSetting.TRACK_KEY, "old": str(not on), "new": str(on)})
