extends GutTest
## Character portraits on the character select cards (DS-CMP-08 썸네일): the character's own model
## on a small stage, redrawn every frame only while live (focused or picked) to save the GPU.


func test_portrait_shows_the_character_model_and_goes_still_when_not_live() -> void:
	var p := CharacterPortrait.new()
	add_child_autofree(p)
	p.setup(CharacterCatalog.for_character(CharacterData.MAGE, 0), GameConfig.new())
	await wait_process_frames(2)
	assert_not_null(p.model(), "the model loaded")
	assert_eq(p.custom_minimum_size, Vector2(DS.CARD_WIDTH - DS.S5 * 2, DS.CARD_THUMB_HEIGHT))
	p.set_live(true)
	assert_eq(p.viewport().render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE,
			"live, but never drawn while the select screen hides under the arena screen or the match")
	p.set_live(false)
	assert_eq(p.viewport().render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_every_portrait_wears_its_style_gear_and_idle() -> void:
	for id: String in CharacterData.IDS:
		var p := CharacterPortrait.new()
		add_child_autofree(p)
		p.setup(CharacterCatalog.for_character(id, 0), GameConfig.new())
		await wait_process_frames(1)
		var look := StyleGearCatalog.look_for(id, CharacterData.style_of(id))
		assert_eq(p.gear().worn(), id, "%s is dressed like in the match" % id)
		var hat := p.model().find_children(String(look["headgear"]), "MeshInstance3D", true, false)
		assert_true(not hat.is_empty() and (hat[0] as MeshInstance3D).visible, "%s headgear shows" % id)
		assert_false(p.gear().hand_gear().is_empty(), "%s hand gear (gloves, sword or staff)" % id)
		assert_eq(p.animator().clip_for(AnimMap.Anim.IDLE), String(look["idle_clip"]),
				"%s idles in its style stance" % id)
