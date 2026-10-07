extends GutTest
## Combat effects (combat-motion B1-B3): projectile flashes and blasts, special flourishes, grab grips.

const DT := 1.0 / 60.0


func _fx() -> CombatFxLayer:
	var fx := CombatFxLayer.new(GameConfig.new())
	add_child_autofree(fx)
	return fx


func _fighter(id: int, state: int, special: String = "", ticks: int = 0, partner: int = Fighter.NONE) -> Dictionary:
	return {"id": id, "pos": Vector3(id * 2.0, 0, 0), "facing": Vector3(1, 0, 0), "state": state,
			"special": special, "attack_ticks": ticks, "attack_kind": AttackSet.Kind.SPECIAL, "partner_id": partner}


func _view(fighters: Array) -> Dictionary:
	return {"fighters": fighters, "projectiles": []}


func _proj_event(type: String, kind: int) -> Dictionary:
	return {"type": type, "id": 0, "owner": 0, "kind": kind, "pos": Vector3(1, 1, 0)}


func test_a_shot_flashes_at_the_hand() -> void:
	var fx := _fx()
	fx.on_events([_proj_event("projectile_spawn", Projectile.Kind.BOLT)])
	assert_eq(fx.active_bursts().size(), 1, "a muzzle flash where the bolt leaves")


func test_the_fireball_blast_fills_its_radius() -> void:
	var fx := _fx()
	var c := GameConfig.new()
	fx.on_events([_proj_event("projectile_expire", Projectile.Kind.FIREBALL)])
	var bursts := fx.active_bursts()
	assert_eq(bursts.size(), 1)
	assert_almost_eq(bursts[0].reach(), c.fireball_explode_radius, 0.001, "the blast shows the hit radius")
	fx.on_events([_proj_event("projectile_hit", Projectile.Kind.BOLT)])
	var small := fx.active_bursts().filter(func(b: MagicBurst) -> bool: return b.reach() < 1.5)
	assert_eq(small.size(), 1, "a bolt pops small")


func test_bursts_fade_and_free_their_slot() -> void:
	var fx := _fx()
	fx.on_events([_proj_event("projectile_hit", Projectile.Kind.HEAVY_BOLT)])
	for i: int in 120:
		fx.advance(DT)
	assert_eq(fx.active_bursts().size(), 0, "short effects return to rest")


func test_the_pool_caps_live_effects() -> void:
	var fx := _fx()
	var base := fx.get_child_count()
	for i: int in 100:
		fx.on_events([_proj_event("projectile_spawn", Projectile.Kind.BOLT)])
	assert_lte(fx.active_bursts().size(), fx.burst_cap())
	assert_eq(fx.get_child_count(), base, "pooled: no new node per shot")


func test_special_start_bursts_an_aura() -> void:
	var fx := _fx()
	fx.on_events([{"type": "special_start", "fighter": 1, "character": "mage", "special": "big_fireball",
			"pos": Vector3.ZERO}])
	assert_eq(fx.active_bursts().size(), 1)


func test_a_grab_pops_a_grip_and_the_held_fighter_wears_it() -> void:
	var fx := _fx()
	fx.on_events([{"type": "grab", "attacker": 0, "target": 1, "pos": Vector3(1, 0, 0)}])
	assert_eq(fx.grab_fx().active_pops(), 1, "a connecting grab reads")
	var holding := _fighter(0, Fighter.State.HOLDING, "", 0, 1)
	var held := _fighter(1, Fighter.State.HELD, "", 0, 0)
	fx.sync(_view([holding, held]), _view([holding, held]), 1.0, DT)
	assert_true(fx.grab_fx().band_visible(1), "the held fighter shows the grip")
	assert_false(fx.grab_fx().band_visible(0))
	var free := _fighter(1, Fighter.State.IDLE)
	fx.sync(_view([holding, free]), _view([holding, free]), 1.0, DT)
	assert_false(fx.grab_fx().band_visible(1), "released: grip gone")


func test_special_phases() -> void:
	var c := GameConfig.new()
	var a := SpecialCatalog.attack(SpecialCatalog.GROUND_SLAM, c)
	assert_eq(SpecialFx.phase(a.startup_ticks, a), SpecialFx.Phase.STARTUP)
	assert_eq(SpecialFx.phase(a.startup_ticks + 1, a), SpecialFx.Phase.ACTIVE)
	assert_eq(SpecialFx.phase(a.startup_ticks + a.active_ticks + 1, a), SpecialFx.Phase.RECOVERY)


func test_ground_slam_shockwave_on_the_active_frame() -> void:
	var fx := _fx()
	var c := GameConfig.new()
	var a := SpecialCatalog.attack(SpecialCatalog.GROUND_SLAM, c)
	_play(fx, SpecialCatalog.GROUND_SLAM, 1, a.startup_ticks)
	assert_eq(fx.active_bursts().size(), 0, "nothing before the slam lands")
	_play(fx, SpecialCatalog.GROUND_SLAM, a.startup_ticks + 1, a.startup_ticks + 3)
	var waves := fx.active_bursts()
	assert_eq(waves.size(), 1, "one shockwave per slam")
	assert_almost_eq(waves[0].reach(), c.slam_radius, 0.001, "the ring reaches the slam radius")


func test_spin_slash_arc_shows_while_active() -> void:
	var fx := _fx()
	var a := SpecialCatalog.attack(SpecialCatalog.SPIN_SLASH, GameConfig.new())
	_play(fx, SpecialCatalog.SPIN_SLASH, 1, a.startup_ticks)
	assert_false(fx.special_fx().arc_visible(0))
	_play(fx, SpecialCatalog.SPIN_SLASH, a.startup_ticks + 1, a.startup_ticks + 2)
	assert_true(fx.special_fx().arc_visible(0), "the swirl is out while the blade sweeps")
	_play(fx, SpecialCatalog.SPIN_SLASH, a.total_ticks() - 2, a.total_ticks() - 1)
	for i: int in 30:
		fx.advance(DT)
	assert_false(fx.special_fx().arc_visible(0), "it fades out after the sweep")


func test_big_fireball_charges_in_the_hand() -> void:
	var fx := _fx()
	var a := SpecialCatalog.attack(SpecialCatalog.BIG_FIREBALL, GameConfig.new())
	_play(fx, SpecialCatalog.BIG_FIREBALL, 1, 2)
	assert_true(fx.special_fx().orb_visible(0))
	var early := fx.special_fx().orb_scale(0)
	_play(fx, SpecialCatalog.BIG_FIREBALL, 3, a.startup_ticks)
	assert_gt(fx.special_fx().orb_scale(0), early, "the orb grows through the windup")
	_play(fx, SpecialCatalog.BIG_FIREBALL, a.startup_ticks + 1, a.startup_ticks + 2)
	assert_false(fx.special_fx().orb_visible(0), "it leaves as the real fireball")


func test_dash_rush_leaves_afterimages() -> void:
	var fx := _fx()
	var a := SpecialCatalog.attack(SpecialCatalog.DASH_RUSH, GameConfig.new())
	_play(fx, SpecialCatalog.DASH_RUSH, 1, a.startup_ticks)
	assert_eq(fx.special_fx().streak_count(), 0)
	_play(fx, SpecialCatalog.DASH_RUSH, a.startup_ticks + 1, a.startup_ticks + 12)
	assert_gt(fx.special_fx().streak_count(), 1, "ghosts trail the rush")


func test_a_fighter_leaving_its_special_drops_its_effects() -> void:
	var fx := _fx()
	var a := SpecialCatalog.attack(SpecialCatalog.BIG_FIREBALL, GameConfig.new())
	assert_lt(4, a.startup_ticks)
	_play(fx, SpecialCatalog.BIG_FIREBALL, 1, 4)
	var hit := _fighter(0, Fighter.State.HITSTUN)
	fx.sync(_view([hit]), _view([hit]), 1.0, DT)
	assert_false(fx.special_fx().orb_visible(0), "a hit cancels the charge")


## Fighter 0 in `special` from attack tick `from` to `to`, one tick per frame.
func _play(fx: CombatFxLayer, special: String, from: int, to: int) -> void:
	for t: int in range(from, to + 1):
		var f := _fighter(0, Fighter.State.SPECIAL, special, t)
		fx.sync(_view([f]), _view([f]), 1.0, DT)
		fx.advance(DT)


func test_the_match_stage_draws_projectiles_and_clears_them() -> void:
	var c := GameConfig.new()
	var stage := MatchStage.new()
	add_child_autofree(stage)
	stage.setup(c, 0, 2)
	var view := World.new(c, 0, 2).state_view()
	view["projectiles"] = [{"id": 0, "owner": 0, "kind": Projectile.Kind.FIREBALL, "pos": Vector3(1, 1, 0),
			"vel": Vector3.ZERO, "radius": c.fireball_radius, "ticks_left": 10}]
	stage.draw(view, view, 1.0, DT)
	stage.on_events([_proj_event("projectile_spawn", Projectile.Kind.FIREBALL)])
	var layers := stage.find_children("*", "ProjectileLayer", true, false)
	assert_eq(layers.size(), 1)
	assert_eq((layers[0] as ProjectileLayer).view_count(), 1, "the fireball is drawn")
	stage.clear_items()
	assert_eq((layers[0] as ProjectileLayer).view_count(), 0, "a new match starts empty")
