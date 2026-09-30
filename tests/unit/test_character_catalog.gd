extends GutTest
## KayKit characters (context F3): four slots, loadable glb scenes with animations, and every
## hidden accessory name really exists in its scene.


func _mesh_names(node: Node, out: Array[String]) -> void:
	if node is MeshInstance3D:
		out.append(String(node.name))
	for c: Node in node.get_children():
		_mesh_names(c, out)


func test_four_player_slots_cycle() -> void:
	assert_eq(CharacterCatalog.CHARACTERS.size(), 4)
	assert_eq(CharacterCatalog.for_player(0)["name"], "Knight")
	assert_eq(CharacterCatalog.for_player(4)["name"], "Knight", "slots wrap around")


func test_every_character_loads_with_animations() -> void:
	for c: Dictionary in CharacterCatalog.CHARACTERS:
		var scene := load(String(c["path"])) as PackedScene
		assert_not_null(scene, String(c["path"]))
		var root := scene.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, "%s has one AnimationPlayer" % c["name"])
		assert_gt((players[0] as AnimationPlayer).get_animation_list().size(), 20, "%s ships its clips" % c["name"])
		var meshes: Array[String] = []
		_mesh_names(root, meshes)
		for hidden: String in c["hide"]:
			assert_has(meshes, hidden, "%s: hidden accessory %s exists" % [c["name"], hidden])
		root.free()


func test_a_character_id_picks_its_own_model_whatever_the_slot() -> void:
	for id: String in CharacterData.IDS:
		for slot: int in 4:
			assert_eq(String(CharacterCatalog.for_character(id, slot)["name"]).to_lower(), id,
					"%s in slot %d wears its own model" % [id, slot])
	assert_eq(CharacterCatalog.for_character(CharacterData.DEFAULT, 2), CharacterCatalog.for_player(2),
			"the classic fighter keeps the slot model")
