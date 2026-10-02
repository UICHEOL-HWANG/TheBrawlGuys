class_name GloveModel
extends ItemModel
## Feather glove (design.md DS-VIS-05, PRD-ITEM-06): a puffy cream mitten with a thumb, a
## petal-blue cuff and a soft glow-yellow feather plume, so its hit reads as "light", not heavy.
## Origin on the ground under the glove.

const FIST := Vector3(0.17, 0.15, 0.15)
const THUMB_RADIUS := 0.065
const CUFF_RADIUS := 0.11
const CUFF_HEIGHT := 0.09
const PLUME := Vector3(0.05, 0.2, 0.12)
## On the hand, fist outward (handslot.r axes as in BombModel.HOLD: -x up, +z outward).
const HOLD := Transform3D(Vector3(0, 0.9, 0), Vector3(-0.9, 0, 0), Vector3(0, 0, 0.9), Vector3(0.06, 0, 0.14))


func hold_transform() -> Transform3D:
	return HOLD


func _build() -> void:
	var fist_y := FIST.y
	_part(ItemParts.sphere(1.0), DS.STONE_CREAM, ItemParts.at(Vector3(0, fist_y, 0), Vector3.ZERO, FIST))
	_part(ItemParts.sphere(THUMB_RADIUS), DS.STONE_CREAM,
			ItemParts.at(Vector3(FIST.x * 0.7, fist_y + FIST.y * 0.35, FIST.z * 0.55)))
	_part(ItemParts.cylinder(CUFF_RADIUS, CUFF_RADIUS * 1.1, CUFF_HEIGHT), DS.PETAL_BLUE,
			ItemParts.at(Vector3(-FIST.x * 0.95, fist_y, 0), Vector3(0, 0, PI * 0.5)))
	_part(ItemParts.sphere(1.0), DS.GLOW,
			ItemParts.at(Vector3(-FIST.x * 1.1, fist_y + FIST.y * 1.1, 0), Vector3(0, 0, 0.5), PLUME))
