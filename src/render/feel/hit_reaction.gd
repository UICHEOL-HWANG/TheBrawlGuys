class_name HitReaction
extends Node
## Who hit whom, on the bodies (design.md DS-VFX-08). The victim flashes white through hitstop,
## squashes and shudders back along the hit direction; a melee attacker holds a small forward
## lunge while frozen. Render only: moves and scales the fighter's model node under its
## FighterView (the view itself follows the sim), and puts everything back when done.

const FLASH_FADE := 0.1
const FLASH_ALPHA := 0.85
const SETTLE := 0.14
const JOLT_HZ := 16.0
const MIN_HOLD := 0.05
## Victim push-back (m) and squash per ImpactTier.
const JOLT_DISTANCE := [0.1, 0.16, 0.26]
const SQUASH := [Vector3(1.06, 0.94, 1.06), Vector3(1.1, 0.9, 1.1), Vector3(1.18, 0.82, 1.18)]
const LUNGE_DISTANCE := 0.16
const LUNGE_SQUASH := Vector3(0.96, 1.05, 0.96)

var _target: Node3D = null
var _rest_pos: Vector3 = Vector3.ZERO
var _rest_scale: Vector3 = Vector3.ONE
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _active: bool = false
var _struck: bool = false
var _age: float = 0.0
var _hold: float = 0.0
var _dir: Vector3 = Vector3.RIGHT
var _distance: float = 0.0
var _squash: Vector3 = Vector3.ONE


## target: the node drawn for the fighter (CharacterModel), or null (nothing to react).
func setup(target: Node3D) -> void:
	_target = target
	if target == null:
		return
	_rest_pos = target.position
	_rest_scale = target.scale
	if target is MeshInstance3D:
		_meshes.append(target as MeshInstance3D)
	for n: Node in target.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = DS.HIT_FLASH


## A sim hit on the stage: victim flash and jolt; a melee attacker also lunges (render only).
static func react(e: Dictionary, views: Array[FighterView], reactions: Array[HitReaction], config: GameConfig) -> void:
	var target := int(e["target"])
	var attacker := int(e["attacker"])
	if target < 0 or target >= views.size():
		return
	var melee := e.has("attack_kind") and attacker >= 0 and attacker < views.size()
	var at: Vector3 = e["pos"]
	var from := views[attacker].position if melee else at
	var dir := ImpactTier.hit_direction(views[target].position, at, from, melee)
	var hold := float(e["hitstop_ticks"]) / SimTime.TICK_RATE
	reactions[target].struck(dir, ImpactTier.of(float(e["knockback"]), config), hold)
	if melee and attacker != target:
		reactions[attacker].strike(dir, hold)


## The victim side: flash + jolt along dir (world, flat), sized by the hit tier.
func struck(dir: Vector3, tier: int, hold: float) -> void:
	var t := clampi(tier, ImpactTier.Tier.LIGHT, ImpactTier.Tier.HEAVY)
	_begin(dir, hold, JOLT_DISTANCE[t], SQUASH[t], true)
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _flash_mat


## The attacker side: a forward lunge held through hitstop. A running victim reaction wins.
func strike(dir: Vector3, hold: float) -> void:
	if _active and _struck:
		return
	_begin(dir, hold, LUNGE_DISTANCE, LUNGE_SQUASH, false)


func _process(delta: float) -> void:
	if _active:
		advance(delta)


func advance(delta: float) -> void:
	if not _active or _target == null:
		return
	_age += delta
	if _age >= _hold + maxf(SETTLE, FLASH_FADE):
		_finish()
		return
	var push := jolt(_age, _hold) if _struck else lunge(_age, _hold)
	_target.position = _rest_pos + _local(_dir) * _distance * push
	_target.scale = _rest_scale * Vector3.ONE.lerp(_squash, lunge(_age, _hold))
	if _struck:
		var c := DS.HIT_FLASH
		c.a = flash_amount(_age, _hold) * FLASH_ALPHA
		_flash_mat.albedo_color = c


## 1 through hitstop, then a linear fade over FLASH_FADE.
static func flash_amount(t: float, hold: float) -> float:
	if t <= hold:
		return 1.0
	return clampf(1.0 - (t - hold) / FLASH_FADE, 0.0, 1.0)


## Victim push along the hit direction: starts fully pushed, shudders and decays to rest.
static func jolt(t: float, hold: float) -> float:
	var span := hold + SETTLE
	if t >= span:
		return 0.0
	return cos(t * JOLT_HZ * TAU) * (1.0 - t / span)


## Attacker lunge: held during hitstop, eases back over SETTLE.
static func lunge(t: float, hold: float) -> float:
	if t <= hold:
		return 1.0
	return clampf(1.0 - (t - hold) / SETTLE, 0.0, 1.0)


func _begin(dir: Vector3, hold: float, distance: float, squash: Vector3, struck_side: bool) -> void:
	if _target == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	_dir = flat.normalized() if flat.length() > 0.0 else Vector3.ZERO
	_hold = maxf(hold, MIN_HOLD)
	_distance = distance
	_squash = squash
	_struck = struck_side
	_age = 0.0
	_active = true
	advance(0.0)


func _finish() -> void:
	_active = false
	_struck = false
	_target.position = _rest_pos
	_target.scale = _rest_scale
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = null


## A world direction in the target's parent space (the FighterView turns with the facing).
func _local(world_dir: Vector3) -> Vector3:
	var parent := _target.get_parent() as Node3D
	if parent == null or not parent.is_inside_tree():
		return world_dir
	return parent.global_basis.orthonormalized().inverse() * world_dir
