class_name CrateModel
extends ItemModel
## Falling item crate (design.md DS-VIS-05, Phase 4 T8): a dark core wrapped in light wooden
## planks on every side and the lid, held by two metal bands. Origin at the bottom center.

const SIZE := 0.7
const PLANKS_PER_SIDE := 3
## Plank gap: the dark core shows between boards.
const PLANK_GAP := 0.03
const PLANK_DEPTH := 0.04
const BAND_WIDTH := 0.08
const BAND_DEPTH := 0.05
## Bands sit this far from the center along z.
const BAND_OFFSET := 0.22


func _build() -> void:
	_part(ItemParts.box(Vector3.ONE * (SIZE - PLANK_DEPTH)), DS.BARK, ItemParts.at(Vector3(0, SIZE * 0.5, 0)))
	var board := (SIZE - PLANK_GAP * (PLANKS_PER_SIDE + 1)) / PLANKS_PER_SIDE
	for side: int in 4:
		_side_planks(side * PI * 0.5, board)
	_lid_planks(board)
	for z: float in [-BAND_OFFSET, BAND_OFFSET]:
		_band(z)


## Horizontal boards on one side face (the face turned by `yaw` around the crate center).
func _side_planks(yaw: float, board: float) -> void:
	var half := SIZE * 0.5
	for k: int in PLANKS_PER_SIDE:
		var y := PLANK_GAP + board * 0.5 + k * (board + PLANK_GAP)
		var pos := Vector3(0, y, half - PLANK_DEPTH * 0.5).rotated(Vector3.UP, yaw)
		_part(ItemParts.box(Vector3(SIZE - PLANK_GAP, board, PLANK_DEPTH)), DS.DIRT,
				ItemParts.at(pos, Vector3(0, yaw, 0)))


func _lid_planks(board: float) -> void:
	for k: int in PLANKS_PER_SIDE:
		var x := -SIZE * 0.5 + PLANK_GAP + board * 0.5 + k * (board + PLANK_GAP)
		_part(ItemParts.box(Vector3(board, PLANK_DEPTH, SIZE - PLANK_GAP)), DS.DIRT,
				ItemParts.at(Vector3(x, SIZE - PLANK_DEPTH * 0.5, 0)))


## One metal band over the lid and down both x faces at depth z.
func _band(z: float) -> void:
	var half := SIZE * 0.5
	var outer := SIZE + BAND_DEPTH
	_part(ItemParts.box(Vector3(outer, BAND_DEPTH, BAND_WIDTH)), DS.STONE_SHADE,
			ItemParts.at(Vector3(0, SIZE + BAND_DEPTH * 0.5 - PLANK_DEPTH * 0.5, z)))
	for sx: float in [-1.0, 1.0]:
		_part(ItemParts.box(Vector3(BAND_DEPTH, SIZE, BAND_WIDTH)), DS.STONE_SHADE,
				ItemParts.at(Vector3(sx * (half + BAND_DEPTH * 0.5 - PLANK_DEPTH * 0.5), half, z)))
