class_name HammerModel
extends ItemModel
## Squeaky toy hammer (design.md DS-VIS-05, PRD-ITEM-05): a petal-blue handle and a fat pink
## squeak drum across the top with yellow bumper caps, so it reads as a toy next to the wooden
## bat. Built along +Y from the grip end; lies along x on the ground.

const HANDLE_LENGTH := 0.56
const HANDLE_RADIUS := 0.045
const HEAD_RADIUS := 0.15
const HEAD_LENGTH := 0.38
const CAP_LENGTH := 0.05
const GRIP_POINT := 0.12
## Grip at the hand slot, head up along the slot's +Y (like BatModel.HOLD).
const HOLD := Transform3D(Basis.IDENTITY, Vector3(0, -GRIP_POINT, 0))


func hold_transform() -> Transform3D:
	return HOLD


## On its side along x, resting on the drum.
func ground_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-HANDLE_LENGTH * 0.5, HEAD_RADIUS, 0))


func _build() -> void:
	_part(ItemParts.cylinder(HANDLE_RADIUS, HANDLE_RADIUS, HANDLE_LENGTH), DS.PETAL_BLUE,
			ItemParts.at(Vector3(0, HANDLE_LENGTH * 0.5, 0)))
	var head_y := HANDLE_LENGTH + HEAD_RADIUS * 0.6
	var across := Vector3(0, 0, PI * 0.5)  # the drum lies across the handle
	_part(ItemParts.cylinder(HEAD_RADIUS, HEAD_RADIUS, HEAD_LENGTH), DS.PETAL_PINK,
			ItemParts.at(Vector3(0, head_y, 0), across))
	for side: float in [-1.0, 1.0]:
		var x := side * (HEAD_LENGTH + CAP_LENGTH) * 0.5
		_part(ItemParts.cylinder(HEAD_RADIUS * 1.08, HEAD_RADIUS * 1.08, CAP_LENGTH), DS.PETAL_YELLOW,
				ItemParts.at(Vector3(x, head_y, 0), across))
