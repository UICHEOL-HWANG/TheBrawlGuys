class_name BatModel
extends ItemModel
## Wooden bat (design.md DS-VIS-05, Phase 4 T8): a tapered wooden barrel, a pink grip-tape
## handle with wraps and a knob. Cracks spread over the barrel as swings run out, so the last
## swing reads at a glance. Built along +Y from the knob; lies along x on the ground.

const LENGTH := 0.9
const BARREL_RADIUS := 0.11
const HANDLE_RADIUS := 0.045
const GRIP_LENGTH := 0.26
const KNOB_RADIUS := 0.06
const WRAP_COUNT := 2
const MAX_CRACKS := 3
## Crack streak: size and where each one sits (height along the bat, angle around it).
const CRACK_SIZE := Vector3(0.018, 0.16, 0.02)
const CRACKS: Array[Vector2] = [Vector2(0.72, 0.4), Vector2(0.58, 2.3), Vector2(0.8, 4.1)]
const CRACK_TILT := 0.45
## The hand grips the middle of the tape.
const GRIP_POINT := 0.14
## Grip at the hand slot, barrel up along the slot's +Y.
const HOLD := Transform3D(Basis.IDENTITY, Vector3(0, -GRIP_POINT, 0))

var max_uses: int = 5
var _cracks: Array[Node3D] = []


static func crack_stage(uses: int, p_max_uses: int) -> int:
	if uses >= p_max_uses:
		return 0
	if p_max_uses <= 1:
		return MAX_CRACKS
	var worn := float(p_max_uses - uses) / float(p_max_uses - 1)
	return clampi(ceili(worn * MAX_CRACKS - 0.0001), 1, MAX_CRACKS)


func show_state(view: Dictionary, _tick: int) -> void:
	var stage := crack_stage(int(view.get("uses", max_uses)), max_uses)
	for i: int in _cracks.size():
		_cracks[i].visible = i < stage


func cracks_shown() -> int:
	var n := 0
	for c: Node3D in _cracks:
		if c.visible:
			n += 1
	return n


func hold_transform() -> Transform3D:
	return HOLD


## Lying on its side along x, centered, resting on the barrel.
func ground_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-LENGTH * 0.5, BARREL_RADIUS, 0))


func _build() -> void:
	_part(ItemParts.sphere(KNOB_RADIUS), DS.BARK, ItemParts.at(Vector3(0, KNOB_RADIUS * 0.6, 0)))
	_part(ItemParts.cylinder(HANDLE_RADIUS, HANDLE_RADIUS, GRIP_LENGTH), DS.PETAL_PINK,
			ItemParts.at(Vector3(0, GRIP_LENGTH * 0.5, 0)))
	for k: int in WRAP_COUNT:
		var y := GRIP_LENGTH * float(k + 1) / float(WRAP_COUNT + 1)
		_part(ItemParts.cylinder(HANDLE_RADIUS * 1.25, HANDLE_RADIUS * 1.25, 0.025), DS.BERRY,
				ItemParts.at(Vector3(0, y, 0)))
	var barrel := LENGTH - GRIP_LENGTH - BARREL_RADIUS
	_part(ItemParts.cylinder(BARREL_RADIUS, HANDLE_RADIUS, barrel), DS.DIRT,
			ItemParts.at(Vector3(0, GRIP_LENGTH + barrel * 0.5, 0)))
	_part(ItemParts.sphere(BARREL_RADIUS), DS.DIRT, ItemParts.at(Vector3(0, LENGTH - BARREL_RADIUS, 0)))
	for c: Vector2 in CRACKS:
		_cracks.append(_crack(c.x * LENGTH, c.y))


## A dark zig-zag streak on the barrel surface at height y, turned `angle` around the bat.
func _crack(y: float, angle: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation.y = angle
	add_child(pivot)
	var radius := lerpf(HANDLE_RADIUS, BARREL_RADIUS, (y - GRIP_LENGTH) / (LENGTH - GRIP_LENGTH))
	for k: int in 2:
		var side := 1.0 if k == 0 else -1.0
		var at := Vector3(0, y + side * CRACK_SIZE.y * 0.35, radius)
		_part(ItemParts.box(CRACK_SIZE), DS.CANOPY_DEEP, ItemParts.at(at, Vector3(0, 0, side * CRACK_TILT)), pivot)
	pivot.visible = false
	return pivot
