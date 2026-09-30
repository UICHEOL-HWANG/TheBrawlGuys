class_name MockupTrim
extends RefCounted
## Direction B (Phase 5 T8 gate): the style reads from one accent color worn as glowing trim.
## Boxing = fire wrist wraps, weapon = petal-blue sash across the chest, ranged = berry hand orb
## plus a berry circlet. Shapes stay small: this direction bets on color, not silhouette.

const ACCENT := {
	StyleMockup.Style.BOXING: DS.FIRE,
	StyleMockup.Style.WEAPON: DS.PETAL_BLUE,
	StyleMockup.Style.RANGED: DS.BERRY,
}
const WRAP_RADIUS := 0.14
const WRAP_THICKNESS := 0.07
const SASH_RADIUS := 0.36
const SASH_THICKNESS := 0.07
const SASH_TILT_DEG := 40.0
const CIRCLET_RADIUS := 0.34
const CIRCLET_THICKNESS := 0.045
const CIRCLET_LIFT := 0.3
const HAND_ORB_RADIUS := 0.13


static func accent(style: int) -> Color:
	return ACCENT.get(style, DS.FIRE)


static func dress(model: CharacterModel, style: int) -> void:
	var mat := StyleMockup.glow_material(accent(style))
	match style:
		StyleMockup.Style.BOXING:
			for bone: String in MockupGear.HANDS:
				StyleMockup.attach(model, bone, _ring(WRAP_RADIUS, WRAP_THICKNESS, mat, Vector3.ZERO))
		StyleMockup.Style.WEAPON:
			StyleMockup.attach(model, "chest", _ring(SASH_RADIUS, SASH_THICKNESS, mat, Vector3(0.0, 0.0, SASH_TILT_DEG)))
		StyleMockup.Style.RANGED:
			var orb := StyleMockup.mesh_node(StyleMockup.sphere(HAND_ORB_RADIUS), mat)
			StyleMockup.attach(model, "handslot.r", orb)
			var circlet := _ring(CIRCLET_RADIUS, CIRCLET_THICKNESS, mat, Vector3.ZERO)
			StyleMockup.attach(model, "head", circlet)
			circlet.position.y += CIRCLET_LIFT / maxf(model.model_scale(), 0.0001)


## A thin glowing torus (outer radius r) rotated by tilt degrees.
static func _ring(r: float, thickness: float, mat: Material, tilt_deg: Vector3) -> Node3D:
	var torus := TorusMesh.new()
	torus.outer_radius = r
	torus.inner_radius = r - thickness
	var holder := Node3D.new()
	var ring := StyleMockup.mesh_node(torus, mat)
	ring.rotation_degrees = tilt_deg
	holder.add_child(ring)
	return holder
