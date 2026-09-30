class_name KeyHintHud
extends Control
## Places the KeyHintBar (design.md DS-CMP-16) at the bottom center of the match HUD, inside the
## safe area with the s5 margin (DS-LAY-02: info top, controls bottom), and drives it: caps follow
## the local player's InputMap actions every frame, F2 or the chip hides/shows the keys, the choice
## lives in SettingsStore [hud] key_hints and each change tracks settings_changed. The whole bar
## steps aside while touch controls are active (they own the bottom of the screen).

const BAR_SCENE := preload("res://src/ui/components/key_hint_bar/key_hint_bar.tscn")
const TOGGLE_ACTION := "hud_key_hints"
const SECTION := "hud"
const KEY := "key_hints"
const TRACK_KEY := "hud.key_hints"

var _margin: MarginContainer
var _bar: KeyHintBar
var _caps: Array[Dictionary] = []
var _touch_active: Callable
var _store: SettingsStore
var _track: Callable


## touch_active() -> bool: true while touch controls are on screen.
func setup(accent: Color, touch_active: Callable, store: SettingsStore, track: Callable) -> void:
	_touch_active = touch_active
	_store = store
	_track = track
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_bar = BAR_SCENE.instantiate() as KeyHintBar
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_margin.add_child(_bar)
	_bar.set_accent(accent)
	_bar.toggle_requested.connect(toggle)
	_caps = KeyHintSource.caps()
	var shown := store.get_bool(SECTION, KEY, true)
	_bar.set_state(KeyHintBar.State.SHOWN if shown else KeyHintBar.State.HIDDEN, false)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_refresh()


func bar() -> KeyHintBar:
	return _bar


func is_shown() -> bool:
	return _bar.state() == KeyHintBar.State.SHOWN


func toggle() -> void:
	var old := is_shown()
	_bar.set_state(KeyHintBar.State.HIDDEN if old else KeyHintBar.State.SHOWN)
	_store.set_value(SECTION, KEY, not old)
	_track.call("settings_changed", {"key": TRACK_KEY, "old": str(old), "new": str(not old)})


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _bar == null:
		return
	visible = not bool(_touch_active.call())
	if not visible or not is_shown():
		return
	for c: Dictionary in _caps:
		_bar.set_pressed(String(c["id"]), KeyHintSource.is_held(c["actions"]))


func _unhandled_input(event: InputEvent) -> void:
	if _bar != null and visible and event.is_action_pressed(TOGGLE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


## Bottom, left and right margins: s5 inside the device safe area (DS-LAY-02).
func _apply_safe_area() -> void:
	var vp := get_viewport().get_visible_rect()
	var safe := SafeArea.rect(get_viewport())
	_margin.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S5)
	_margin.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S5)
	_margin.add_theme_constant_override("margin_bottom", int(vp.end.y - safe.end.y) + DS.S5)
