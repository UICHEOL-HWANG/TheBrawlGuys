extends GutTest
## Defense VFX (combat-depth A, DefenseFx): dodge afterimages, a guard bubble that shrinks with the
## guard meter and flashes when low, dizzy stars on a broken guard, a ring flash on a perfect guard.


func _view(state: int, ratio: float = 1.0, dodging: bool = false, broken: bool = false) -> Dictionary:
	return {"state": state, "pos": Vector3.ZERO, "is_dodging": dodging, "guard_hp_ratio": ratio,
			"guard_broken": broken}


func _fx() -> Array:
	var c := GameConfig.new()
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(0, c)
	var fx := DefenseFx.new()
	view.add_child(fx)
	fx.setup(0, c, view)
	return [view, fx]


func test_dodging_leaves_afterimages_and_fades_the_fighter() -> void:
	var fx: DefenseFx = _fx()[1]
	fx.apply(_view(Fighter.State.DODGE, 1.0, true), DodgeGhosts.GHOST_INTERVAL)
	assert_true(fx.faded(), "semi-transparent while intangible")
	assert_gt(fx.ghost_count(), 0, "an afterimage")
	fx.apply(_view(Fighter.State.IDLE), DodgeGhosts.GHOST_INTERVAL)
	assert_false(fx.faded())


func test_bubble_shrinks_with_the_meter_and_flashes_when_low() -> void:
	var pair := _fx()
	var view: FighterView = pair[0]
	var fx: DefenseFx = pair[1]
	fx.apply(_view(Fighter.State.GUARD, 1.0), 0.016)
	var full := (view.bubble().mesh as SphereMesh).radius
	fx.apply(_view(Fighter.State.GUARD, 0.5), 0.016)
	assert_lt((view.bubble().mesh as SphereMesh).radius, full, "a weaker guard is a smaller bubble")
	var seen := {}
	for i: int in 30:
		fx.apply(_view(Fighter.State.GUARD, DefenseFx.LOW_RATIO * 0.5), 0.016)
		seen[view.bubble().material_override] = true
	assert_eq(seen.size(), 2, "the low bubble flashes between two looks")


func test_broken_guard_shows_dizzy_stars() -> void:
	var fx: DefenseFx = _fx()[1]
	fx.apply(_view(Fighter.State.HITSTUN, 0.3, false, true), 0.016)
	assert_true(fx.stars_visible())
	fx.apply(_view(Fighter.State.IDLE, 0.3), 0.016)
	assert_false(fx.stars_visible())


func test_perfect_guard_flashes_a_ring() -> void:
	var fx: DefenseFx = _fx()[1]
	var before := fx.get_child_count()
	fx.perfect_flash()
	assert_true(fx.ring_visible())
	assert_eq(fx.get_child_count(), before, "the ring is built once and replayed")
	fx.apply(_view(Fighter.State.IDLE), PerfectRing.LIFE + 0.01)
	assert_false(fx.ring_visible(), "gone after its life")


func test_afterimages_are_pooled() -> void:
	var fx: DefenseFx = _fx()[1]
	var before := fx.get_child_count()
	var nodes := -1
	for i: int in 40:
		fx.apply(_view(Fighter.State.DODGE, 1.0, true), DodgeGhosts.GHOST_INTERVAL)
		if i == 0:
			nodes = _node_count(fx)
	assert_eq(_node_count(fx), nodes, "no node per afterimage")
	assert_eq(fx.get_child_count(), before)
	assert_lte(fx.ghost_count(), DodgeGhosts.pool_size())
	fx.apply(_view(Fighter.State.IDLE), DS.MOTION_BASE + 0.01)
	assert_eq(fx.ghost_count(), 0, "every afterimage fades out")


func test_dizzy_stars_are_big_inked_flat_stars_above_the_head() -> void:
	assert_gt(DizzyStars.RADIUS, 0.2, "readable from the top-down camera")
	var fx: DefenseFx = _fx()[1]
	fx.apply(_view(Fighter.State.HITSTUN, 0.3, false, true), 0.016)
	var stars := fx.get_children().filter(func(n: Node) -> bool: return n is DizzyStars)
	assert_eq(stars.size(), 1)
	var meshes := (stars[0] as Node).find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), DizzyStars.COUNT * 2, "each star has an ink rim")
	assert_true((meshes[0] as MeshInstance3D).mesh is ArrayMesh, "a flat star shape")


func _node_count(root: Node) -> int:
	return root.find_children("*", "", true, false).size()
