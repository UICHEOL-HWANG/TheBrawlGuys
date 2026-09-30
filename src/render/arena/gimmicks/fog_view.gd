class_name FogView
extends GimmickView
## Periodic fog (fog gimmick; PRD-ARENA-04, DS-THM-02 "주기적으로 짙어짐"): while the sim reports
## the fog active, layered mist sheets and drifting mist banks fade in over the whole arena and
## fade out after. fog_amount() (0..1) also drives the distance fog (EnvironmentRig) and the
## fighter silhouettes that stay visible above it (FogSilhouette, DS-VIS-03).

const FADE_TIME := 1.2
## Mist sheet heights: under the knees, at the waist, over the heads.
const SHEET_HEIGHTS: Array[float] = [0.35, 1.0, 1.9]
const SHEET_SIZE := 44.0
const BANK_COUNT := 10
const BANK_RADIUS := 2.6
const BANK_FLATTEN := 0.35
const BANK_SPREAD := 12.0
const BANK_DRIFT := 0.5
## gl_compatibility (web) stacks the translucent sheets far heavier (the arena vanished in a compat
## capture); its veil alpha is scaled down until the arena core reads through the mist again.
const VEIL_ALPHA_COMPAT := 0.4

var _amount: float = 0.0
var _target: float = 0.0
var _material: StandardMaterial3D
var _banks: Array[MeshInstance3D] = []
var _bank_phase: Array[float] = []
var _alpha_scale: float = 1.0
## Amount last written to the veil (-1 = never): the veil only changes while the fog fades.
var _applied: float = -1.0


func fog_amount() -> float:
	return _amount


func veil_material() -> StandardMaterial3D:
	return _material


func mist_visible() -> bool:
	return _banks.size() > 0 and _banks[0].visible


func _build(_view: Dictionary) -> void:
	position = Vector3.ZERO  # arena-wide: no area
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_alpha_scale = VEIL_ALPHA_COMPAT if compat else 1.0
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = DS.FOG_VEIL
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(SHEET_SIZE, SHEET_SIZE)
	for h: float in SHEET_HEIGHTS:
		_banks.append(_mesh(sheet, _material, Vector3(0, h, 0)))
	var puff := SphereMesh.new()
	puff.radius = BANK_RADIUS
	puff.height = BANK_RADIUS * 2.0 * BANK_FLATTEN
	var rng := RandomNumberGenerator.new()
	rng.seed = gimmick_id + 1
	for i: int in BANK_COUNT:
		var p := Vector3(rng.randf_range(-BANK_SPREAD, BANK_SPREAD), rng.randf_range(0.6, 1.6),
				rng.randf_range(-BANK_SPREAD, BANK_SPREAD))
		_banks.append(_mesh(puff, _material, p))
		_bank_phase.append(rng.randf() * TAU)
	_apply()


func _follow(view: Dictionary, delta: float) -> void:
	_target = 1.0 if bool(view.get("active", false)) else 0.0
	_amount = move_toward(_amount, _target, delta / FADE_TIME)
	for i: int in _bank_phase.size():
		var bank := _banks[SHEET_HEIGHTS.size() + i]
		bank.position.x += sin(_time * 0.2 + _bank_phase[i]) * BANK_DRIFT * delta
	_apply()


func _apply() -> void:
	if _amount == _applied:
		return
	_applied = _amount
	var c := DS.FOG_VEIL
	c.a = DS.FOG_VEIL.a * _amount * _alpha_scale
	_material.albedo_color = c
	for b: MeshInstance3D in _banks:
		b.visible = _amount > 0.001
