class_name FighterIdentity
extends Node3D
## Who a fighter is (design.md DS-VIS-03): the foot ring in the player's color AND shape (P1
## circle, P2 triangle, P3 square, P4 diamond — PlayerRingMesh, readable in black and white) and
## the "P1" label over the head. Origin at the fighter's feet. The menu backdrop hides it.

const RING_INNER_RATIO := 1.15
const RING_OUTER_RATIO := 1.45
const RING_LIFT := 0.02
const LABEL_GAP := 0.6
const LABEL_PIXEL_SIZE := 0.01

var _ring: MeshInstance3D
var _label: Label3D
var _shape: int = PlayerStyle.Shape.CIRCLE


func setup(index: int, config: GameConfig) -> void:
	_shape = PlayerStyle.shape(index)
	_ring = MeshInstance3D.new()
	_ring.mesh = PlayerRingMesh.build(_shape, config.fighter_radius * RING_INNER_RATIO,
			config.fighter_radius * RING_OUTER_RATIO)
	_ring.position.y = RING_LIFT
	_ring.material_override = ToonMaterials.toon(PlayerStyle.color(index))
	add_child(_ring)
	_label = Label3D.new()
	_label.text = PlayerStyle.label(index)
	_label.font = load(DS.FONT_DISPLAY_PATH) as Font
	_label.font_size = DS.SIZE_TITLE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = DS.UI_SURFACE
	_label.outline_modulate = DS.CANOPY_DEEP
	_label.outline_size = DS.TEXT_OUTLINE * 2
	_label.position.y = config.fighter_height + LABEL_GAP
	add_child(_label)


func set_shown(on: bool) -> void:
	_ring.visible = on
	_label.visible = on


func is_shown() -> bool:
	return _label.visible


func ring() -> MeshInstance3D:
	return _ring


func ring_shape() -> int:
	return _shape


func label() -> Label3D:
	return _label
