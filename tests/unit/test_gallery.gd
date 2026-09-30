extends GutTest
## Every sound and effect is previewable in the DS gallery (design.md DS-GOV-02).

const VFX_KINDS: Array[String] = ["hit_small", "hit_large", "dust", "trail", "splash", "star", "respawn", "charge"]


func test_gallery_lists_every_sfx_and_vfx() -> void:
	var g := (load("res://src/debug/ds_gallery.tscn") as PackedScene).instantiate()
	add_child_autofree(g)
	await wait_process_frames(2)
	for name: String in SfxRecipes.RECIPES:
		assert_not_null(g.find_child("sfx_" + name, true, false), "sfx button for %s" % name)
	for kind: String in VFX_KINDS:
		assert_not_null(g.find_child("vfx_" + kind, true, false), "vfx button for %s" % kind)
	for name: String in ["bgm_battle", "bgm_intense", "bgm_menu"]:
		assert_not_null(g.find_child(name, true, false), name)


func test_pressing_a_vfx_button_spawns_the_effect() -> void:
	var g := (load("res://src/debug/ds_gallery.tscn") as PackedScene).instantiate()
	add_child_autofree(g)
	await wait_process_frames(2)
	var stage := g.find_child("vfx_stage", true, false) as Node3D
	var before := stage.get_child_count()
	(g.find_child("vfx_dust", true, false) as Button).pressed.emit()
	assert_gt(stage.get_child_count(), before, "the dust puff appears on the preview stage")
