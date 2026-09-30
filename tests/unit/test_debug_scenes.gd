extends GutTest
## Smoke test: every debug scene must load, instantiate and survive a few process frames.

const DEBUG_DIR := "res://src/debug"


func _scene_paths() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(DEBUG_DIR):
		if f.ends_with(".tscn"):
			out.append("%s/%s" % [DEBUG_DIR, f])
	return out


func test_there_are_debug_scenes() -> void:
	assert_gt(_scene_paths().size(), 0)


func test_every_debug_scene_runs() -> void:
	for path: String in _scene_paths():
		var scene := load(path) as PackedScene
		assert_not_null(scene, "%s loads" % path)
		if scene == null:
			continue
		var node: Node = scene.instantiate()
		assert_not_null(node, "%s instantiates" % path)
		if node == null:
			continue
		add_child(node)
		for i in 5:
			await get_tree().process_frame
		assert_true(is_instance_valid(node), "%s survives frames" % path)
		node.queue_free()
		await get_tree().process_frame
