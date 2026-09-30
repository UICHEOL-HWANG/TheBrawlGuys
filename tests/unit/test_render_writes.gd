extends GutTest
## Per-frame render work stays idle when nothing changed (Phase 4 review): MatchStage.set_arena
## only rebuilds for a new requested id, and the fog boost, fog veil and fog silhouettes skip
## their writes while the fog amount holds still.

const SENTINEL := 0.123


func _stage(id: String) -> MatchStage:
	var s := MatchStage.new()
	add_child_autofree(s)
	s.setup(GameConfig.new(), 3, 1, id)
	return s


func test_unknown_arena_id_does_not_rebuild_every_call() -> void:
	var s := _stage("classic")
	watch_signals(s)
	s.set_arena("nope")
	var built := s.arena_view()
	s.set_arena("nope")
	assert_same(s.arena_view(), built, "the same unknown id is a no-op")
	assert_signal_emit_count(s, "arena_changed", 1)
	s.set_arena("classic")
	assert_signal_emit_count(s, "arena_changed", 2, "a new request still switches")


func test_same_arena_id_is_a_no_op() -> void:
	var s := _stage("log_bridge")
	var built := s.arena_view()
	s.set_arena("log_bridge")
	assert_same(s.arena_view(), built)


func test_fog_boost_skips_the_environment_when_unchanged() -> void:
	var rig := EnvironmentRig.new()
	add_child_autofree(rig)
	rig.setup()
	rig.set_fog_boost(0.5)
	rig.environment().fog_density = SENTINEL
	rig.set_fog_boost(0.5)
	assert_almost_eq(rig.environment().fog_density, SENTINEL, 0.0001, "no write for the same boost")
	rig.set_fog_boost(0.6)
	assert_almost_ne(rig.environment().fog_density, SENTINEL, 0.0001, "a new boost writes")


func test_fog_view_writes_the_veil_only_when_the_amount_moves() -> void:
	var s := _stage("foggy_forest")
	var fog := s.arena_view().gimmick_view(0) as FogView
	var on := {"kind": "fog", "id": 0, "active": true}
	for i: int in 90:
		fog.sync(on, i, 1.0 / 60.0)
	var mat := fog.veil_material()
	mat.albedo_color = Color(SENTINEL, SENTINEL, SENTINEL, SENTINEL)
	fog.sync(on, 91, 1.0 / 60.0)
	assert_almost_eq(mat.albedo_color.a, SENTINEL, 0.0001, "fully in: no veil write")
	fog.sync({"kind": "fog", "id": 0, "active": false}, 92, 1.0 / 60.0)
	assert_almost_ne(mat.albedo_color.a, SENTINEL, 0.0001, "fading out writes again")


func test_fog_silhouette_skips_unchanged_amounts() -> void:
	var f := FogSilhouette.new()
	add_child_autofree(f)
	f.setup(0, GameConfig.new())
	assert_false(f.visible, "hidden after setup")
	f.set_amount(0.5)
	var mat := f.body_material()
	mat.albedo_color = Color(SENTINEL, SENTINEL, SENTINEL, SENTINEL)
	f.set_amount(0.5)
	assert_almost_eq(mat.albedo_color.a, SENTINEL, 0.0001, "same amount: no write")
	f.set_amount(0.0)
	assert_false(f.visible)
	assert_almost_ne(mat.albedo_color.a, SENTINEL, 0.0001)
