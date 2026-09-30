extends GutTest
## Candidate clip names resolved against what the model really ships (context F4).


func test_first_available_candidate_wins() -> void:
	var available := PackedStringArray(["Idle", "Running_B", "Running_A", "Jump_Idle"])
	var map := AnimClips.resolve(available)
	assert_eq(map[AnimMap.Anim.IDLE], "Idle")
	assert_eq(map[AnimMap.Anim.RUN], AnimClips.first_present(AnimClips.CANDIDATES[AnimMap.Anim.RUN], available))


func test_missing_states_fall_back_to_idle() -> void:
	var map := AnimClips.resolve(PackedStringArray(["Idle"]))
	for a: int in AnimMap.Anim.values():
		assert_eq(map[a], "Idle", "state %d falls back to idle" % a)


func test_no_idle_uses_the_first_clip() -> void:
	var map := AnimClips.resolve(PackedStringArray(["Dance"]))
	assert_eq(map[AnimMap.Anim.KO], "Dance")


func test_every_anim_has_candidates_and_loop_flags() -> void:
	for a: int in AnimMap.Anim.values():
		assert_true(AnimClips.CANDIDATES.has(a), "candidates for %d" % a)
		assert_gt((AnimClips.CANDIDATES[a] as Array).size(), 0)
	assert_true(AnimClips.loops(AnimMap.Anim.RUN))
	assert_false(AnimClips.loops(AnimMap.Anim.LIGHT))


func test_kaykit_models_resolve_the_core_states() -> void:
	# every core state finds a real clip in each imported character (T2), not the idle fallback
	for c: Dictionary in CharacterCatalog.CHARACTERS:
		var root := (load(String(c["path"])) as PackedScene).instantiate()
		var player := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var available := PackedStringArray()
		for n: StringName in player.get_animation_list():
			available.append(String(n))
		var map := AnimClips.resolve(available)
		for a: int in [AnimMap.Anim.RUN, AnimMap.Anim.JUMP, AnimMap.Anim.LIGHT, AnimMap.Anim.HIT, AnimMap.Anim.GUARD]:
			assert_ne(map[a], map[AnimMap.Anim.IDLE], "%s: state %d has its own clip" % [c["name"], a])
		root.free()
