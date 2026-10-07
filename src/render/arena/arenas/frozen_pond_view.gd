class_name FrozenPondView
extends ArenaDressing
## Frozen pond (얼음 연못): open cold water (WaterView, the ring-out zone) all around the ice, a
## snowy bank past it with snow-capped pines and snow mounds, a few ice floes drifting in the
## water and light snowfall (Snowfall) over everything. The ice itself is IceFloorMesh and the
## breakable patches IcePatchView. Bank pines that would hide the fight are left out (GD-CAM-01).

const BANK_INNER := 12.5
const BANK_OUTER := 70.0
const BANK_TOP := -0.2
const BANK_EDGE := 1.4
const PINES := 12
const PINE_RING := Vector2(15.0, 24.0)
const PINE_SIZE := Vector2(1.1, 1.7)
const CAP_RADIUS := 0.55
const CAP_HEIGHT := 0.7
const MOUNDS := 8
const MOUND_RADIUS := 1.1
const MOUND_FLATTEN := 0.45
const FLOES := 7
const FLOE_RADIUS := Vector2(0.4, 0.9)
const FLOE_LIFT := 0.03
## Floes keep this far off the ice edge and the bank.
const FLOE_CLEARANCE := 0.8

var _snow: Snowfall


func prop_ground(p: Vector3) -> float:
	return BANK_TOP if Vector2(p.x, p.z).length() >= BANK_INNER + ZONE_MARGIN else NAN


func make_prop(rng: RandomNumberGenerator, i: int) -> Dictionary:
	if i % TREE_EVERY != 0:
		return super(rng, i)
	var size := rng.randf_range(PINE_SIZE.x, PINE_SIZE.y)
	var pine := _snowy_pine(size)
	return {"node": pine["node"], "radius": PineTree.TIERS[0].x * size, "height": pine["height"]}


func inner_flowers() -> bool:
	return false


func outer_flowers() -> bool:
	return false


func snowfall() -> Snowfall:
	return _snow


func _build() -> void:
	_bank()
	_bank_pines()
	_mounds()
	_floes(_water_line())
	_snow = Snowfall.new()
	add_child(_snow)
	_snow.setup(_config, SpecialCutInDirector.reduce_motion_setting(SettingsStore.new()))


func _water_line() -> float:
	for z: ArenaShape in _arena.ringout_zones:
		return z.center.y
	return DecorView.GROUND_Y


func _bank() -> void:
	var top := MeshInstance3D.new()
	top.mesh = IceFloorMesh.annulus(BANK_OUTER, BANK_INNER)
	top.material_override = ToonMaterials.toon(_theme.outer_ground)
	top.position.y = BANK_TOP
	add_child(top)
	var edge := MeshInstance3D.new()
	edge.mesh = IceFloorMesh.wall(BANK_INNER, BANK_EDGE, false)
	edge.material_override = ToonMaterials.toon(_theme.floor_lip)
	edge.position.y = BANK_TOP
	add_child(edge)


func _bank_pines() -> void:
	var poses := DecorOcclusion.match_poses(_config, _arena)
	for i: int in PINES:
		var a := TAU * (i + _rng.randf()) / PINES
		var d := _rng.randf_range(PINE_RING.x, PINE_RING.y)
		var size := _rng.randf_range(PINE_SIZE.x, PINE_SIZE.y)
		var base := Vector3(cos(a) * d, BANK_TOP, sin(a) * d)
		var radius := PineTree.TIERS[0].x * size
		var pine := _snowy_pine(size)
		if DecorOcclusion.blocks_any(poses, base, radius, pine["height"]):
			(pine["node"] as Node3D).free()
			continue
		var node: Node3D = pine["node"]
		node.position = base
		add_child(node)
		add_occluder(node, radius, pine["height"])


## A pine with a snow cap on its top tier: {node, height}.
func _snowy_pine(size: float) -> Dictionary:
	var pine := PineTree.new()
	var height := pine.setup(_theme.canopy, size)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = CAP_RADIUS * size
	cap.height = CAP_HEIGHT * size
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.material_override = ToonMaterials.toon(DS.WHITE)
	mi.position.y = height - CAP_HEIGHT * size * 0.5
	pine.add_child(mi)
	return {"node": pine, "height": height}


func _mounds() -> void:
	var dome := SphereMesh.new()
	dome.radius = MOUND_RADIUS
	dome.height = MOUND_RADIUS * 2.0
	for i: int in MOUNDS:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(BANK_INNER + 1.5, PINE_RING.x)
		var mi := _piece(dome, DS.WHITE, Vector3(cos(a) * d, BANK_TOP, sin(a) * d))
		mi.scale = Vector3(_rng.randf_range(1.0, 1.8), MOUND_FLATTEN, _rng.randf_range(1.0, 1.6))


func _floes(water_y: float) -> void:
	var floe := CylinderMesh.new()
	floe.top_radius = 1.0
	floe.bottom_radius = 1.0
	floe.height = 0.08
	floe.radial_segments = 7
	var ice := _arena.view_radius() + FLOE_CLEARANCE
	for i: int in FLOES:
		var a := TAU * (i + _rng.randf_range(0.2, 0.8)) / FLOES
		var d := _rng.randf_range(ice, BANK_INNER - FLOE_CLEARANCE)
		var mi := _piece(floe, _theme.floor_top, Vector3(cos(a) * d, water_y + FLOE_LIFT, sin(a) * d))
		var r := _rng.randf_range(FLOE_RADIUS.x, FLOE_RADIUS.y)
		mi.scale = Vector3(r, 1.0, r * _rng.randf_range(0.6, 1.0))
		mi.rotation.y = _rng.randf() * TAU
