extends GutTest
## VictoryPose (polish-pass 6): each character celebrates its own way, and the cheer clip goes
## back to the default when the ceremony ends.


func _view(character: String) -> FighterView:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new(), character)
	return v


func test_each_character_has_its_own_victory_motion() -> void:
	var clips := {}
	for id: String in CharacterData.IDS:
		clips[VictoryPose.clip_for(id)] = true
	assert_gte(clips.size(), 3, "not everyone does the same cheer")
	assert_eq(VictoryPose.clip_for("knight"), "Spellcast_Raise", "the knight raises his sword")
	assert_eq(VictoryPose.clip_for(""), "Cheer", "the classic fighter cheers")


func test_winners_play_their_character_clip_and_reset_after() -> void:
	var views: Array[FighterView] = [_view("knight"), _view("barbarian")]
	var pose := VictoryPose.new()
	pose.start(views, [0])
	assert_eq(views[0].animator().clip_for(AnimMap.Anim.CHEER), "Spellcast_Raise")
	pose.start(views, [])
	assert_eq(views[0].animator().clip_for(AnimMap.Anim.CHEER), "Cheer", "next match: default again")


func test_every_victory_clip_ships_in_the_kaykit_pack() -> void:
	for id: String in CharacterData.IDS:
		var v := _view(id)
		assert_true(v.model().animation_player().has_animation(VictoryPose.clip_for(id)), id)
