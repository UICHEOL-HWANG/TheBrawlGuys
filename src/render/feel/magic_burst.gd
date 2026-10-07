class_name MagicBurst
extends Node3D
## A one-shot glowing burst (combat-motion B): a hot flash sphere that pops and fades, a soft
## halo that swells, a flat ring racing out to `reach` and sparks flung outward (optionally
## rising). The look Dictionary (BurstLooks) picks colors, sizes and timing, so one pooled node
## covers muzzle flashes, bolt pops, the fireball blast, special auras and shockwaves.

const MAX_SPARKS := 18
const RING_THICKNESS := 0.14
## Fraction of the life the flash takes to pop to full size.
const POP_SHARE := 0.22
const HALO_SCALE := 1.35
const HALO_ALPHA := 0.45
const RING_ALPHA := 0.9
## The ring tube is flattened to this share of its scale (a disc edge, not a donut).
const RING_FLATTEN := 0.35

var _flash: MeshInstance3D
var _halo: MeshInstance3D
var _ring: MeshInstance3D
var _sparks: Array[MeshInstance3D] = []
var _dirs: Array[Vector3] = []
var _look: Dictionary = {}
var _age: float = 0.0
var _life: float = 0.3
var _flash_alpha: float = 1.0
var _halo_alpha: float = HALO_ALPHA
var _active: bool = false


func _init() -> void:
	_halo = FxMaterials.sphere(self, 1.0, DS.WHITE, false, 0)
	_flash = FxMaterials.sphere(self, 1.0, DS.WHITE, false, 2)
	_ring = FxMaterials.ring(self, RING_THICKNESS, DS.WHITE, false, 1)
	for i: int in MAX_SPARKS:
		_sparks.append(FxMaterials.sphere(self, 1.0, DS.WHITE, false, 1))
		_dirs.append(spark_dir(i, MAX_SPARKS))
	visible = false


## Evenly spread directions on the upper part of a sphere (golden angle), mostly sideways.
static func spark_dir(i: int, count: int) -> Vector3:
	var y := lerpf(0.75, -0.15, (float(i) + 0.5) / float(count))
	var r := sqrt(maxf(1.0 - y * y, 0.0))
	var a := float(i) * 2.39996
	return Vector3(cos(a) * r, y, sin(a) * r)


## Starts the burst at `at` with `look` (BurstLooks); `sparks` overrides the look's spark count.
func play(at: Vector3, look: Dictionary, sparks: int = -1) -> void:
	position = at
	_look = look
	_life = maxf(float(look.get("life", 0.3)), 0.01)
	_age = 0.0
	_flash_alpha = float(look.get("flash_alpha", 1.0))
	_halo_alpha = float(look.get("halo_alpha", HALO_ALPHA))
	var count := clampi(int(look.get("sparks", 0)) if sparks < 0 else sparks, 0, MAX_SPARKS)
	FxMaterials.tint(_flash, look.get("core", DS.WHITE))
	FxMaterials.tint(_halo, look.get("halo", DS.GLOW), _halo_alpha)
	FxMaterials.tint(_ring, look.get("ring", DS.WHITE), RING_ALPHA)
	_ring.visible = reach() > 0.0
	_ring.position.y = float(look.get("ring_y", 0.0))
	var colors: Array = look.get("spark", [DS.GLOW])
	for i: int in MAX_SPARKS:
		_sparks[i].visible = i < count
		FxMaterials.tint(_sparks[i], colors[i % colors.size()])
	_active = true
	visible = true
	advance(0.0)


## Ages the burst (its BurstPool calls this every frame).
func advance(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if _age >= _life:
		stop()
		return
	var t := _age / _life
	var out := 1.0 - (1.0 - t) * (1.0 - t)
	var size := float(_look.get("size", 0.5))
	var pop := 1.0 - pow(1.0 - minf(t / POP_SHARE, 1.0), 3.0)
	_flash.scale = Vector3.ONE * size * lerpf(0.3, 1.0, pop) * lerpf(1.0, 0.55, t * t)
	FxMaterials.set_alpha(_flash, _flash_alpha * (1.0 - smoothstep(0.25, 1.0, t)))
	_halo.scale = Vector3.ONE * size * HALO_SCALE * lerpf(0.5, 1.15, out)
	FxMaterials.set_alpha(_halo, _halo_alpha * (1.0 - t))
	var ring := reach() * lerpf(0.15, 1.0, out)
	_ring.scale = Vector3(ring, maxf(ring * RING_FLATTEN, 0.01), ring)
	FxMaterials.set_alpha(_ring, RING_ALPHA * (1.0 - t * t))
	_fling(out, t)


func _fling(out: float, t: float) -> void:
	var travel := float(_look.get("spark_speed", 3.0)) * _life * 0.5 * out
	var rise := Vector3.UP * float(_look.get("rise", 0.0)) * out
	var s := float(_look.get("spark_size", 0.1)) * (1.0 - t)
	for i: int in MAX_SPARKS:
		if _sparks[i].visible:
			_sparks[i].position = _dirs[i] * travel + rise * (0.6 + 0.4 * float(i % 3))
			_sparks[i].scale = Vector3.ONE * maxf(s, 0.001)


func stop() -> void:
	_active = false
	visible = false


func active() -> bool:
	return _active


## How far the burst's ring reaches (0: no ring).
func reach() -> float:
	return float(_look.get("reach", 0.0))


func spark_count() -> int:
	return _sparks.filter(func(s: MeshInstance3D) -> bool: return s.visible).size()
