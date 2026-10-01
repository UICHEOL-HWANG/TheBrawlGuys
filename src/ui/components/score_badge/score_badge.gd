class_name ScoreBadge
extends Label
## Timed match score (combat-depth D, design.md DS-CMP-21): in the PlayerCard where stock
## matches show StockIcons, "3점" in Jua with the deep-teal outline; bumps when it changes,
## danger red below 0.

const BUMP_SCALE := 1.3

var _score: int = 0


func _ready() -> void:
	add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	add_theme_font_size_override("font_size", DS.SIZE_TITLE)
	add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_apply()


func set_score(score: int) -> void:
	if score == _score:
		return
	_score = score
	_apply()
	if is_inside_tree():
		UiMotion.bump(self, BUMP_SCALE)


func score() -> int:
	return _score


func _apply() -> void:
	text = "%d점" % _score
	add_theme_color_override("font_color", DS.DANGER if _score < 0 else DS.UI_SURFACE)


func set_preview() -> void:
	if not is_node_ready():
		await ready
	set_score(3)
