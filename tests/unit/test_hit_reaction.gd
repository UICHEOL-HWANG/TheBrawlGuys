extends GutTest
## Victim flash and jolt, attacker lunge (design.md DS-VFX-08). Render only.

const HOLD := 0.1


func _rig() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)
	var model := Node3D.new()
	model.position = Vector3(0, 0.25, 0)
	root.add_child(model)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	var reaction := HitReaction.new()
	root.add_child(reaction)
	reaction.setup(model)
	return [reaction, model, mesh]


func test_flash_holds_through_hitstop_then_fades_out() -> void:
	assert_eq(HitReaction.flash_amount(0.0, HOLD), 1.0)
	assert_eq(HitReaction.flash_amount(HOLD, HOLD), 1.0)
	var mid := HitReaction.flash_amount(HOLD + HitReaction.FLASH_FADE * 0.5, HOLD)
	assert_gt(mid, 0.0)
	assert_lt(mid, 1.0)
	assert_eq(HitReaction.flash_amount(HOLD + HitReaction.FLASH_FADE + 0.01, HOLD), 0.0)


func test_jolt_starts_pushed_back_and_settles_to_zero() -> void:
	assert_almost_eq(HitReaction.jolt(0.0, HOLD), 1.0, 0.0001)
	assert_eq(HitReaction.jolt(HOLD + HitReaction.SETTLE + 0.01, HOLD), 0.0)
	var late := absf(HitReaction.jolt(HOLD + HitReaction.SETTLE * 0.8, HOLD))
	assert_lt(late, 0.5, "the shudder decays")


func test_lunge_holds_forward_during_hitstop_then_returns() -> void:
	assert_eq(HitReaction.lunge(HOLD * 0.5, HOLD), 1.0)
	assert_eq(HitReaction.lunge(HOLD + HitReaction.SETTLE + 0.01, HOLD), 0.0)


func test_struck_flashes_and_jolts_the_model_then_restores_it() -> void:
	var rig := _rig()
	var reaction: HitReaction = rig[0]
	var model: Node3D = rig[1]
	var mesh: MeshInstance3D = rig[2]
	reaction.struck(Vector3(1, 0, 0), ImpactTier.Tier.HEAVY, HOLD)
	reaction.advance(0.0)
	assert_not_null(mesh.material_overlay, "white flash on the victim")
	assert_gt(model.position.x, 0.0, "pushed along the hit direction")
	assert_ne(model.scale, Vector3.ONE, "squashed")
	reaction.advance(1.0)
	assert_null(mesh.material_overlay, "flash cleared")
	assert_eq(model.position, Vector3(0, 0.25, 0), "back at rest")
	assert_eq(model.scale, Vector3.ONE)


func test_strike_lunges_the_attacker_forward_without_flash() -> void:
	var rig := _rig()
	var reaction: HitReaction = rig[0]
	var model: Node3D = rig[1]
	var mesh: MeshInstance3D = rig[2]
	reaction.strike(Vector3(0, 0, -1), HOLD)
	reaction.advance(0.02)
	assert_lt(model.position.z, 0.0)
	assert_null(mesh.material_overlay)
	reaction.advance(1.0)
	assert_eq(model.position, Vector3(0, 0.25, 0))


func test_no_model_is_harmless() -> void:
	var reaction := HitReaction.new()
	add_child_autofree(reaction)
	reaction.setup(null)
	reaction.struck(Vector3(1, 0, 0), ImpactTier.Tier.LIGHT, HOLD)
	reaction.advance(0.05)
	assert_true(true, "no crash without a model")
