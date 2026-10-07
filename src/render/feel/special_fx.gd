class_name SpecialFx
extends Node3D
## Per-special flourishes (combat-motion B2), timed off each fighter view in SPECIAL (attack_ticks
## against the special's AttackData): ground_slam -> a shockwave ring out to slam_radius plus dust
## on the first active tick; dash_rush -> afterimages every RUSH_EVERY ticks while rushing;
## spin_slash -> a whirling slash arc while the sweep is active; big_fireball -> a flame orb
## growing in the Mage's hand through the windup (the real fireball takes over on release).
## Leaving SPECIAL (a hit, the end) drops the fighter's effects. Never writes to the sim.

enum Phase { STARTUP, ACTIVE, RECOVERY }

const RUSH_EVERY := 2
## The Mage's casting hand: above the feet (m) and ahead along the facing (m).
const HAND_UP := 1.0
const HAND_FORWARD := 0.45
## The charge orb grows from ORB_FROM to ORB_TO of the fireball's look through the windup.
const ORB_FROM := 0.2
const ORB_TO := 0.85
const SLAM_LIFT := 0.08

var _config: GameConfig
var _bursts: BurstPool
var _particle_scale: float = 1.0
var _streak: RushStreak
var _last: Dictionary = {}
var _arcs: Dictionary = {}
var _orbs: Dictionary = {}
var _attacks: Dictionary = {}


func setup(config: GameConfig, bursts: BurstPool, particle_scale: float) -> void:
	_config = config
	_bursts = bursts
	_particle_scale = particle_scale
	_streak = RushStreak.new()
	add_child(_streak)


func set_particle_scale(particle_scale: float) -> void:
	_particle_scale = particle_scale


static func phase(attack_ticks: int, a: AttackData) -> int:
	if attack_ticks <= a.startup_ticks:
		return Phase.STARTUP
	return Phase.ACTIVE if a.is_active(attack_ticks) else Phase.RECOVERY


## Every frame with the current fighter views.
func apply(fighters: Array) -> void:
	var seen := {}
	for f: Dictionary in fighters:
		var special := String(f.get("special", ""))
		if int(f.get("state", Fighter.State.IDLE)) != Fighter.State.SPECIAL or special.is_empty():
			continue
		var id := int(f["id"])
		seen[id] = true
		_special(f, id, special)
	for id: int in _last.keys():
		if not seen.has(id):
			_end(id)


func _special(f: Dictionary, id: int, special: String) -> void:
	var a := _attack(special)
	var ticks := int(f["attack_ticks"])
	var last := int(_last.get(id, 0))
	if ticks < last:
		last = 0  # a new special started between frames
	_last[id] = ticks
	var at: Vector3 = f["pos"]
	var color := PlayerStyle.color(id)
	match special:
		SpecialCatalog.GROUND_SLAM:
			if last <= a.startup_ticks and ticks > a.startup_ticks:
				_slam(at, color)
		SpecialCatalog.DASH_RUSH:
			if phase(ticks, a) == Phase.ACTIVE and _rush_step(ticks, a) != _rush_step(maxi(last, a.startup_ticks), a):
				_streak.emit(at, f.get("facing", Vector3.FORWARD), color)
		SpecialCatalog.SPIN_SLASH:
			_arc(id, color).show_at(at, phase(ticks, a) == Phase.ACTIVE)
		SpecialCatalog.BIG_FIREBALL:
			_charge(id, f, ticks, a)


func _slam(at: Vector3, color: Color) -> void:
	_bursts.play(at + Vector3.UP * SLAM_LIFT, BurstLooks.shockwave(_config.slam_radius, color))
	var dust := DustPuff.new()
	add_child(dust)
	dust.play(at, 1.0, _particle_scale)


## Which afterimage step the rush is on (a new step leaves a ghost).
static func _rush_step(ticks: int, a: AttackData) -> int:
	return floori(float(ticks - a.startup_ticks) / RUSH_EVERY)


func _charge(id: int, f: Dictionary, ticks: int, a: AttackData) -> void:
	var orb := _orb(id)
	orb.visible = phase(ticks, a) == Phase.STARTUP
	if not orb.visible:
		return
	var facing: Vector3 = f.get("facing", Vector3.FORWARD)
	orb.position = (f["pos"] as Vector3) + Vector3.UP * HAND_UP + facing * HAND_FORWARD
	var t := clampf(float(ticks) / maxf(a.startup_ticks, 1.0), 0.0, 1.0)
	orb.scale = Vector3.ONE * lerpf(ORB_FROM, ORB_TO, t * (2.0 - t))


func _end(id: int) -> void:
	_last.erase(id)
	if _arcs.has(id):
		(_arcs[id] as SlashArc).release()
	if _orbs.has(id):
		(_orbs[id] as ProjectileView).visible = false


func advance(delta: float) -> void:
	_streak.advance(delta)
	for arc: SlashArc in _arcs.values():
		arc.advance(delta)


func stop_all() -> void:
	_last.clear()
	_streak.stop_all()
	for arc: SlashArc in _arcs.values():
		arc.stop()
	for orb: ProjectileView in _orbs.values():
		orb.visible = false


func arc_visible(id: int) -> bool:
	return _arcs.has(id) and (_arcs[id] as SlashArc).visible


func orb_visible(id: int) -> bool:
	return _orbs.has(id) and (_orbs[id] as ProjectileView).visible


func orb_scale(id: int) -> float:
	return (_orbs[id] as ProjectileView).scale.x if _orbs.has(id) else 0.0


func streak_count() -> int:
	return _streak.live_count()


func _attack(special: String) -> AttackData:
	if not _attacks.has(special):
		_attacks[special] = SpecialCatalog.attack(special, _config)
	return _attacks[special]


func _arc(id: int, color: Color) -> SlashArc:
	if not _arcs.has(id):
		var arc := SlashArc.new()
		add_child(arc)
		arc.setup(_config.spin_radius * 0.85, color)
		_arcs[id] = arc
	return _arcs[id]


func _orb(id: int) -> ProjectileView:
	if not _orbs.has(id):
		var orb := ProjectileView.new()
		add_child(orb)
		orb.setup(Projectile.Kind.FIREBALL, _config.fireball_radius)
		orb.set_trail_enabled(false)
		_orbs[id] = orb
	return _orbs[id]
