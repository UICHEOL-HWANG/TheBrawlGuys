class_name ProjectileView
extends Node3D
## One flying projectile (combat-motion B1, looks in ProjectileLook): a glowing core, body and
## halo that pulse (the fireball also flickers and licks flames around its body) and a trail of
## shrinking, fading ghosts along the last frames' positions (embers for the fireball). Unshaded,
## so it reads as light from the match camera. Reads projectile view values only.

## Flame licks around the fireball body: count, orbit speed (rad/s), size (fraction of the radius).
const LICKS := 5
const LICK_SPIN := 5.0
const LICK_SIZE := 0.42
## Ember jitter of the fireball trail (fraction of the radius) and its rise per ghost (m).
const EMBER_JITTER := 0.35
const EMBER_RISE := 0.05
## Distance between trail points, in visual radii.
const SAMPLE_STEP := 0.45

var _kind: int = Projectile.Kind.BOLT
var _radius: float = 0.3
var _time: float = 0.0
var _trail_on: bool = true
var _halo: MeshInstance3D
var _body: MeshInstance3D
var _core: MeshInstance3D
var _licks: Array[MeshInstance3D] = []
var _ghosts: Array[MeshInstance3D] = []
var _history: Array[Vector3] = []


## kind: Projectile.Kind; radius: the sim radius (the view's "radius").
func setup(kind: int, radius: float) -> void:
	_kind = kind
	_radius = ProjectileLook.visual_radius(kind, radius)
	var look := ProjectileLook.colors(kind)
	_halo = FxMaterials.sphere(self, _radius, FxMaterials.faded(look["halo"], ProjectileLook.HALO_ALPHA), false, 0)
	_body = FxMaterials.sphere(self, _radius * ProjectileLook.BODY_RATIO,
			FxMaterials.faded(look["body"], ProjectileLook.BODY_ALPHA), false, 1)
	_core = FxMaterials.sphere(self, _radius * ProjectileLook.CORE_RATIO, look["core"], false, 2)
	if kind == Projectile.Kind.FIREBALL:
		for i: int in LICKS:
			_licks.append(FxMaterials.sphere(self, _radius * LICK_SIZE,
					FxMaterials.faded(DS.PETAL_YELLOW if i % 2 == 0 else DS.FIRE, 0.8), false, 1))
	var trail: Array = look["trail"]
	for i: int in ProjectileLook.trail_count(kind):
		var ghost := FxMaterials.sphere(self, _radius * ProjectileLook.BODY_RATIO, trail[i % trail.size()])
		ghost.top_level = true
		ghost.visible = false
		_ghosts.append(ghost)


func apply(prev: Dictionary, curr: Dictionary, alpha: float) -> void:
	var to: Vector3 = curr["pos"]
	position = (prev["pos"] as Vector3).lerp(to, alpha) if not prev.is_empty() else to


## A charge orb in the caster's hand has no trail (it is not flying yet).
func set_trail_enabled(on: bool) -> void:
	_trail_on = on
	_history.clear()
	for g: MeshInstance3D in _ghosts:
		g.visible = false


func _process(delta: float) -> void:
	advance(delta)


## Every frame: pulse, flicker and flames, then the trail follows the head.
func advance(delta: float) -> void:
	_time += delta
	var p := ProjectileLook.pulse(_kind)
	var beat := 1.0 + p.y * sin(_time * TAU * p.x)
	_halo.scale = Vector3.ONE * beat
	_body.scale = Vector3.ONE * (2.0 - beat)
	var flick := ProjectileLook.flicker(_kind) * (0.5 * sin(_time * 23.0) + 0.5 * sin(_time * 37.0 + 1.3))
	_core.scale = Vector3.ONE * (beat + flick)
	_lick_flames()
	if _trail_on and is_inside_tree():
		_follow(global_position)


func _lick_flames() -> void:
	for i: int in _licks.size():
		var a := _time * LICK_SPIN + TAU * float(i) / _licks.size()
		var bob := sin(_time * 11.0 + i * 1.7)
		_licks[i].position = Vector3(cos(a), 0.35 + 0.35 * bob, sin(a)) * _radius * 0.62
		_licks[i].scale = Vector3.ONE * (0.75 + 0.35 * bob)


## Trail points are sampled by distance (every SAMPLE_STEP radii), so the trail keeps its length
## at any frame rate and holds still through hitstop.
func _follow(head: Vector3) -> void:
	if _history.is_empty() or _history[0].distance_to(head) >= _radius * SAMPLE_STEP:
		_history.push_front(head)
		if _history.size() > _ghosts.size() + 1:
			_history.resize(_ghosts.size() + 1)
	for i: int in _ghosts.size():
		var g := _ghosts[i]
		g.visible = i + 1 < _history.size()
		if not g.visible:
			continue
		var t := float(i + 1) / float(_ghosts.size() + 1)
		var at := _history[i + 1]
		if _kind == Projectile.Kind.FIREBALL:
			at += Vector3(sin(_time * 17.0 + i * 2.1), 0.0, cos(_time * 13.0 + i * 1.3)) * _radius * EMBER_JITTER * t
			at.y += EMBER_RISE * (i + 1)
		g.global_position = at
		g.scale = Vector3.ONE * lerpf(0.85, 0.15, t)
		FxMaterials.set_alpha(g, (1.0 - t) * 0.75)


func kind() -> int:
	return _kind


func core_scale() -> float:
	return _core.scale.x


## The oldest trail point (the head while there is no history yet).
func trail_tail() -> Vector3:
	return _history.back() if not _history.is_empty() else position


func trail_length() -> float:
	return trail_tail().distance_to(_history[0]) if not _history.is_empty() else 0.0
