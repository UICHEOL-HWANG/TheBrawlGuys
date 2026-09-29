class_name DamageCounter
extends PanelContainer
## Player damage % (design.md DS-CMP-01): cream pill card with the player's shape badge and a big
## Jua number on the damage ramp, deep-teal outline; squish pop when it rises, dimmed when KO.

const PREVIEW_PLAYER := 0
const PREVIEW_DAMAGE := 42.0
const POP_SCALE := 1.25
const KO_ALPHA := 0.35

var _index: int = 0
var _shown: int = -1
var _marker: PlayerMarker
var _label: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S3)
	add_child(row)
	_marker = PlayerMarker.new()
	row.add_child(_marker)
	_marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = Label.new()
	_label.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	_label.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_XL)
	_label.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	_label.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
	row.add_child(_label)
	setup(_index)
	set_damage(0.0)


func setup(index: int) -> void:
	_index = index
	if _marker != null:
		_marker.setup(index, DS.S7)


func set_damage(p: float) -> void:
	var rounded := roundi(p)
	if _shown >= 0 and rounded > _shown:
		_pop()
	_shown = rounded
	if _label != null:
		_label.text = "%d%%" % rounded
		_label.add_theme_color_override("font_color", DamageColor.for_percent(p))


func set_ko(ko: bool) -> void:
	modulate.a = KO_ALPHA if ko else 1.0


func text() -> String:
	return _label.text if _label != null else ""


func set_preview() -> void:
	if not is_node_ready():
		await ready  # the gallery calls this before the node enters the tree
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	setup(PREVIEW_PLAYER)
	set_damage(PREVIEW_DAMAGE)


func _pop() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	scale = Vector2.ONE * POP_SCALE
	create_tween().tween_property(self, "scale", Vector2.ONE, DS.MOTION_SQUISH) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
