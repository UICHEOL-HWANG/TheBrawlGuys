class_name DodgeGhosts
extends Node3D
## Dodge afterimages (design.md DS-VFX-10): a fixed pool of player-colored capsules sharing one
## mesh, one dropped every GHOST_INTERVAL while dodging and faded out over DS.MOTION_BASE.
## top_level, so afterimages stay where they were left. Nothing is allocated per afterimage: the
## oldest slot is recycled (FxPool).

const GHOST_INTERVAL := 0.05
const GHOST_ALPHA := 0.35

var _pool: FxPool
var _ghosts: Array[MeshInstance3D] = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _clock: float = 0.0
var _lift: float = 0.0


## Enough slots that no afterimage is recycled before it has faded.
static func pool_size() -> int:
	return ceili(DS.MOTION_BASE / GHOST_INTERVAL) + 1


func setup(color: Color, config: GameConfig) -> void:
	top_level = true
	_lift = config.fighter_height * 0.5
	var capsule := CapsuleMesh.new()
	capsule.radius = config.fighter_radius
	capsule.height = config.fighter_height
	var tint := color
	tint.a = GHOST_ALPHA
	_pool = FxPool.new(pool_size())
	for i: int in _pool.size():
		var ghost := MeshInstance3D.new()
		ghost.mesh = capsule
		ghost.material_override = ToonMaterials.translucent(tint).duplicate()
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.visible = false
		add_child(ghost)
		_ghosts.append(ghost)
	_ages.resize(_pool.size())


## Every frame: fades the live afterimages and drops a new one at `at` (the fighter's feet)
## every GHOST_INTERVAL while dodging.
func advance(dodging: bool, at: Vector3, delta: float) -> void:
	_fade(delta)
	if not dodging:
		_clock = 0.0
		return
	_clock += delta
	if _clock >= GHOST_INTERVAL:
		_clock = 0.0
		_drop(at)


func active_count() -> int:
	var n := 0
	for ghost: MeshInstance3D in _ghosts:
		if ghost.visible:
			n += 1
	return n


func _drop(at: Vector3) -> void:
	var slot := _pool.acquire()
	var ghost := _ghosts[slot]
	ghost.position = at + Vector3.UP * _lift  # top_level parent at the origin: local = global
	ghost.visible = true
	_ages[slot] = 0.0
	_set_alpha(ghost, GHOST_ALPHA)


func _fade(delta: float) -> void:
	for i: int in _ghosts.size():
		var ghost := _ghosts[i]
		if not ghost.visible:
			continue
		_ages[i] += delta
		if _ages[i] >= DS.MOTION_BASE:
			ghost.visible = false
		else:
			_set_alpha(ghost, GHOST_ALPHA * (1.0 - _ages[i] / DS.MOTION_BASE))


static func _set_alpha(ghost: MeshInstance3D, alpha: float) -> void:
	var mat := ghost.material_override as StandardMaterial3D
	var c := mat.albedo_color
	c.a = alpha
	mat.albedo_color = c
