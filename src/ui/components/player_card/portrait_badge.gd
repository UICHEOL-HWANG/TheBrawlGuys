class_name PortraitBadge
extends Control
## A PlayerCard's portrait (design.md DS-CMP-22): the character's head (CharacterPortrait in its
## head-shot framing, drawn once) in a cream disc ringed in the player's — or in team mode the
## team's — color, with the player's shape badge (PlayerMarker, DS-VIS-03) on its lower corner so
## the P number reads without color. Tests and evidence can skip the 3D head (with_head = false).
## The HudStrip sets the size per canvas scale (HudStrip.portrait_diameter: s8 desktop, s7 phone).

const DIAMETER := DS.S7
const RING := DS.S1
const BADGE := DS.S3

var _disc: Panel
var _ring: Panel
var _portrait: CharacterPortrait = null
var _marker: PlayerMarker
var _diameter: float = DIAMETER
var _ring_color: Color = DS.UI_TEXT


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc = _layer()
	_disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_ring = _layer()
	_marker = PlayerMarker.new()
	add_child(_marker)


## index: the slot (shape badge, classic model), ring: the frame color (player or team).
func setup(index: int, character: String, config: GameConfig, ring: Color, with_head: bool = true) -> void:
	_ring_color = ring
	_marker.setup(index, BADGE)
	set_diameter(_diameter)
	if with_head and config != null:
		_portrait = CharacterPortrait.new()
		_portrait.head_shot = true
		_portrait.custom_minimum_size = custom_minimum_size
		_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_disc.add_child(_portrait)
		_portrait.setup(CharacterCatalog.for_character(character, index), config)


## Team mode: the shape badge in the team color too.
func set_tint(c: Variant) -> void:
	_marker.set_tint(c)


## Disc, ring and the shape badge in its lower corner at this size (the head follows the disc).
func set_diameter(d: float) -> void:
	_diameter = d
	custom_minimum_size = Vector2(d, d)
	_disc.add_theme_stylebox_override("panel", _round(DS.UI_SURFACE, true, d))
	var edge := _round(_ring_color, false, d)
	edge.set_border_width_all(RING)
	_ring.add_theme_stylebox_override("panel", edge)
	_marker.position = Vector2(d - BADGE, d - BADGE)
	if _portrait != null:
		_portrait.custom_minimum_size = custom_minimum_size


func diameter() -> float:
	return _diameter


func portrait() -> CharacterPortrait:
	return _portrait


func _layer() -> Panel:
	var p := Panel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


static func _round(color: Color, filled: bool, d: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = filled
	sb.bg_color = color
	sb.border_color = color
	sb.set_corner_radius_all(roundi(d * 0.5))
	return sb
