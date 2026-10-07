class_name IcePatchView
extends PlankView
## Frozen pond thin ice patch (platform; design.md DS-VIS-04 "부서질 발판 = 균열이 단계적으로 커짐"):
## a pale-blue slab of thin ice, set apart from the snow-white solid ice so players can tell
## where holes will open. PlankView drives it: hits show a first crack, the break warning grows
## the cracks and shakes the slab, the break sinks it into the water (the hole opens) and the
## refreeze brings it back up.

const THICKNESS := 0.45
## Drawn just above the solid ice where the slab overlaps the outer ring, so the tops never fight.
const LIFT := 0.01
## Crack streaks as fractions of the half size: [x, z, yaw], spread over the whole slab.
const ICE_CRACKS: Array[Vector3] = [Vector3(-0.3, 0.2, 0.6), Vector3(0.35, -0.25, -0.8), Vector3(0.05, 0.45, 1.3),
		Vector3(-0.6, -0.4, -0.3), Vector3(0.65, 0.35, 0.9), Vector3(-0.1, -0.6, -1.2)]


func _build_surface(deck: Node3D, size: Vector2) -> void:
	var slab := Node3D.new()
	slab.position.y = LIFT
	deck.add_child(slab)
	IceFloorMesh.slab(slab, size, _theme.floor_lip, _theme.rim, THICKNESS)


func _surface_lift() -> float:
	return LIFT


func _crack_color() -> Color:
	return DS.WATER_DEEP


func _crack_layout(size: Vector2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c: Vector3 in ICE_CRACKS:
		out.append(Vector3(c.x * size.x * 0.5, c.y * size.y * 0.5, c.z))
	return out
