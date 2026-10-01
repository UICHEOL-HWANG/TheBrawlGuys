class_name MatchTimer
extends PanelContainer
## Timed match clock (combat-depth D, design.md DS-CMP-20): a cream pill like DamageCounter with
## a ClockIcon and the time left as "1:59" in Jua, between the HUD strip's two card groups. The
## final FINAL_SECONDS turn danger red and bump once per second; sudden death shows "서든 데스".

const FINAL_SECONDS := 10
const BUMP_SCALE := 1.2
const SUDDEN_DEATH_TEXT := "서든 데스"

var _label: Label
var _icon: ClockIcon
var _shown_seconds: int = -1
var _sudden: bool = false


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	_label.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	_label.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	add_child(row)
	_icon = ClockIcon.new()
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	row.add_child(_label)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	set_ticks_left(0)


## ticks_left: sim ticks still to play (60 Hz); sudden: sudden death has started.
func set_ticks_left(ticks_left: int, sudden: bool = false) -> void:
	var seconds := ceili(float(ticks_left) / SimTime.TICK_RATE)
	if seconds == _shown_seconds and sudden == _sudden:
		return
	var final := not sudden and seconds <= FINAL_SECONDS and seconds > 0
	if final and seconds < _shown_seconds and is_inside_tree():
		UiMotion.bump(self, BUMP_SCALE)
	_shown_seconds = seconds
	_icon.set_seconds(seconds)
	_sudden = sudden
	_label.text = SUDDEN_DEATH_TEXT if sudden else clock_text(seconds)
	_label.add_theme_color_override("font_color", DS.DANGER if final or sudden else DS.UI_SURFACE)


func text() -> String:
	return _label.text


func is_final() -> bool:
	return _label.get_theme_color("font_color") == DS.DANGER


## "m:ss".
static func clock_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


func set_preview() -> void:
	if not is_node_ready():
		await ready
	set_ticks_left(SimTime.to_ticks(8.0))
