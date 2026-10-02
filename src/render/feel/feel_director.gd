class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): comic impact bursts sized by the knockback tier
## in the attacker's color, damage numbers over the victim, a screen flash and camera punch on
## heavy hits (DS-VFX-01 v2, DS-VFX-09), a blue clang on guarded hits (DS-VFX-07) or a white star
## flash when the same tick says it was a perfect guard (DS-VFX-13), screen shake
## that starts when hitstop ends, a full-strength shake on ring-out and a large puff plus shake on
## bomb explosions. Landing dust and knockback trails come from ViewEvents. Render-side only.
## Bursts and numbers are pooled (ImpactTier.pool_cap, fewer on low quality).

## Explosion shake as a fraction of shake_max.
const EXPLOSION_SHAKE_RATIO := 0.8
## Star roll step between consecutive bursts (radians), so repeated hits do not look stamped.
const ROLL_STEP := 0.9

var _config: GameConfig
var _camera: CameraRig
var _shake: ShakeModel
var _trail: KnockbackTrail
var _decor_lake: bool = ArenaDressings.has_decor_lake(ArenaCatalog.DEFAULT_ID)
var _bursts: Array[ImpactBurst] = []
var _burst_pool: FxPool
var _popups: DamagePopup
var _flash: ScreenFlash
var _hits: int = 0


func setup(config: GameConfig, camera: CameraRig) -> void:
	_config = config
	_camera = camera
	_shake = ShakeModel.new(config)
	_trail = KnockbackTrail.new()
	add_child(_trail)
	_burst_pool = FxPool.new(ImpactTier.pool_cap(Quality.particle_scale(config)))
	for i: int in _burst_pool.size():
		var burst := ImpactBurst.new()
		add_child(burst)
		_bursts.append(burst)
	_popups = DamagePopup.new()
	add_child(_popups)
	_popups.setup(config)
	_flash = ScreenFlash.new()
	add_child(_flash)


## The arena being played (ring-outs splash only where there is water).
func set_arena(arena_id: String) -> void:
	_decor_lake = ArenaDressings.has_decor_lake(arena_id)


## fighters: this tick's fighter views (positions and damage for direction and numbers).
func on_events(events: Array, fighters: Array = []) -> void:
	var perfect := _perfect_guards(events)
	for e: Dictionary in events:
		match String(e["type"]):
			"hit":
				_impact(e, fighters)
				_shake.add(float(e["knockback"]), _hold(e))
			"guard_hit":
				_guarded(e, fighters, perfect.has(int(e["target"])))
			"slip":  # a banana peel: a puff where the feet went out
				var puff := DustPuff.new()
				add_child(puff)
				puff.play(e["pos"], 1.0, Quality.particle_scale(_config))
			"explosion":
				_spark(e["pos"], true)
				_shake.add(_full_shake_knockback() * EXPLOSION_SHAKE_RATIO, 0.0)
			"ringout":
				_shake.add(_full_shake_knockback(), 0.0)
				var at: Vector3 = e["pos"]
				at.y = maxf(at.y, DecorView.GROUND_Y)  # a fighter out at kill_y is far below the ground plane
				var burst := RingoutBurst.new()
				add_child(burst)
				burst.play(at, DecorView.is_water_ringout(e, _config.arena_radius, _decor_lake), PlayerStyle.color(int(e["id"])),
						Quality.particle_scale(_config))
				if _camera != null:
					_camera.punch(1.0)


## Render-side events from ViewEvents (context F8).
func on_view_events(events: Array) -> void:
	var scale := Quality.particle_scale(_config)
	for e: Dictionary in events:
		match String(e["type"]):
			"landed":
				var dust := DustPuff.new()
				add_child(dust)
				dust.play(e["pos"], float(e["intensity"]), scale)
			"respawned":
				var beam := RespawnBeam.new()
				add_child(beam)
				beam.play(e["pos"])
			"trail":
				_trail.add_sample(e["pos"], float(e["intensity"]), PlayerStyle.color(int(e["id"])), scale)


## A restart starts with a still camera (Phase 1 carry-over) and no leftover hit effects.
func reset() -> void:
	_shake = ShakeModel.new(_config)
	for b: ImpactBurst in _bursts:
		b.stop()
	_popups.clear()
	_flash.stop()
	if _camera != null:
		_camera.set_shake_offset(Vector3.ZERO)


func shake_amplitude() -> float:
	return _shake.amplitude()


func _process(delta: float) -> void:
	if _shake == null:
		return
	var offset := _shake.update(delta)
	if _camera != null:
		_camera.set_shake_offset(offset)


func active_bursts() -> Array[ImpactBurst]:
	return _bursts.filter(func(b: ImpactBurst) -> bool: return b.active())


func popups() -> DamagePopup:
	return _popups


func screen_flash() -> ScreenFlash:
	return _flash


## A landed hit: comic burst in the attacker's color, the victim's number, heavy extras.
func _impact(e: Dictionary, fighters: Array) -> void:
	var tier := ImpactTier.of(float(e["knockback"]), _config)
	var attacker := _fighter(fighters, int(e["attacker"]))
	var color := PlayerStyle.color(int(e["attacker"])) if not attacker.is_empty() else DS.FIRE
	var lines := ImpactTier.speed_lines(tier, Quality.particle_scale(_config))
	_hits += 1
	_next_burst().play_hit(e["pos"], _direction(e, fighters), tier, color, _hold(e), lines, _hits * ROLL_STEP)
	var target := _fighter(fighters, int(e["target"]))
	if not target.is_empty():
		_popups.show_hit(target["pos"], float(e["damage"]), float(target["damage"]), tier)
	if tier == ImpactTier.Tier.HEAVY:
		_flash.flash()
		if _camera != null:
			_camera.punch(_config.impact_heavy_punch)


## A guarded hit clangs; a perfect guard (perfect_guard for the same target this tick) flashes.
func _guarded(e: Dictionary, fighters: Array, perfect: bool) -> void:
	_hits += 1
	var burst := _next_burst()
	if perfect:
		burst.play_perfect(e["pos"], _direction(e, fighters), _hold(e), _hits * ROLL_STEP)
	else:
		burst.play_clang(e["pos"], _direction(e, fighters), _hold(e), _hits * ROLL_STEP)


## Fighter ids that perfect-guarded this tick (the sim emits perfect_guard after its guard_hit).
static func _perfect_guards(events: Array) -> Dictionary:
	var ids := {}
	for e: Dictionary in events:
		if String(e["type"]) == "perfect_guard":
			ids[int(e["fighter"])] = true
	return ids


func _direction(e: Dictionary, fighters: Array) -> Vector3:
	var at: Vector3 = e["pos"]
	var target := _fighter(fighters, int(e["target"]))
	var attacker := _fighter(fighters, int(e["attacker"]))
	return ImpactTier.hit_direction(target.get("pos", at), at, attacker.get("pos", at), e.has("attack_kind"))


func _next_burst() -> ImpactBurst:
	return _bursts[_burst_pool.acquire()]


static func _hold(e: Dictionary) -> float:
	return float(e["hitstop_ticks"]) / SimTime.TICK_RATE


static func _fighter(fighters: Array, id: int) -> Dictionary:
	for f: Dictionary in fighters:
		if int(f["id"]) == id:
			return f
	return {}


func _spark(at: Vector3, large: bool) -> void:
	var spark := HitSpark.new()
	add_child(spark)
	spark.play(at, large)


## The knockback whose shake reaches shake_max.
func _full_shake_knockback() -> float:
	return _config.shake_max / maxf(_config.shake_per_knockback, 0.0001)
