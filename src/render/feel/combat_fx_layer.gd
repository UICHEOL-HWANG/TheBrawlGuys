class_name CombatFxLayer
extends Node3D
## World-space combat effects drawn with the match (combat-motion B): flying projectiles
## (ProjectileLayer), a muzzle flash on each shot, a pop where a bolt hits or fizzles and the big
## fireball's blast over its whole hit radius, a power-up aura in the caster's color on
## special_start plus each special's own flourish (SpecialFx), and grab grips (GrabFx). Owned by
## MatchStage, so the match, the tutorial, the finishing replay and the menu backdrop all show them.
## Effects are pooled (BurstPool) and scaled by the quality's particle scale.

var _config: GameConfig
var _projectiles: ProjectileLayer
var _bursts: BurstPool
var _specials: SpecialFx
var _grabs: GrabFx


func _init(config: GameConfig) -> void:
	_config = config
	var particles := Quality.particle_scale(config)
	_projectiles = ProjectileLayer.new()
	add_child(_projectiles)
	_bursts = BurstPool.new()
	add_child(_bursts)
	_bursts.setup(particles)
	_specials = SpecialFx.new()
	add_child(_specials)
	_specials.setup(config, _bursts, particles)
	_grabs = GrabFx.new()
	add_child(_grabs)
	_grabs.setup(_bursts)


## Follows the quality setting (MatchStage.apply_quality): spark and dust counts.
func apply_quality() -> void:
	var particles := Quality.particle_scale(_config)
	_bursts.set_particle_scale(particles)
	_specials.set_particle_scale(particles)


## The views between the previous and current tick (render interpolation), every frame.
func sync(prev: Dictionary, curr: Dictionary, alpha: float, _delta: float) -> void:
	_projectiles.sync(prev.get("projectiles", []), curr.get("projectiles", []), alpha)
	var fighters: Array = curr.get("fighters", [])
	_specials.apply(fighters)
	_grabs.apply(fighters)


## This frame's sim events.
func on_events(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"projectile_spawn":
				_bursts.play(e["pos"], BurstLooks.muzzle(int(e["kind"])))
			"projectile_hit", "projectile_expire":
				var fire := int(e["kind"]) == Projectile.Kind.FIREBALL
				_bursts.play(e["pos"], BurstLooks.explosion(_config) if fire else BurstLooks.impact(int(e["kind"])))
			"special_start":
				var at: Vector3 = e["pos"]
				_bursts.play(at + Vector3.UP * BurstLooks.CHEST, BurstLooks.aura(PlayerStyle.color(int(e["fighter"]))))
			"grab", "hit":
				_grabs.on_event(e)


func _process(delta: float) -> void:
	advance(delta)


## Ages every pooled effect (also called by hand in tests).
func advance(delta: float) -> void:
	_bursts.advance(delta)
	_specials.advance(delta)
	_grabs.advance(delta)


## A new match: no projectiles and no leftover effects.
func clear() -> void:
	_projectiles.clear()
	_bursts.stop_all()
	_specials.stop_all()
	_grabs.stop_all()


func active_bursts() -> Array[MagicBurst]:
	return _bursts.active()


func burst_cap() -> int:
	return _bursts.cap()


func projectile_layer() -> ProjectileLayer:
	return _projectiles


func special_fx() -> SpecialFx:
	return _specials


func grab_fx() -> GrabFx:
	return _grabs
