extends SceneTree
## Lists every animation clip (name, length) and MeshInstance3D path in the KayKit character
## scenes, writing assets/characters/kaykit/animations.txt (Phase 3 Task 2, context F4).
## Run: godot --headless --path . -s res://scripts/list_animations.gd

const DIR := "res://assets/characters/kaykit/"
const NAMES: Array[String] = ["Knight", "Barbarian", "Mage", "Rogue"]
const OUT := "res://assets/characters/kaykit/animations.txt"


func _init() -> void:
	var lines: PackedStringArray = []
	for n: String in NAMES:
		var scene := load(DIR + n + ".glb") as PackedScene
		if scene == null:
			push_error("list_animations: cannot load %s" % n)
			quit(1)
			return
		var root := scene.instantiate()
		lines.append("# %s" % n)
		var player := _find_player(root)
		if player == null:
			lines.append("  (no AnimationPlayer)")
		else:
			var clips := player.get_animation_list()
			for clip: StringName in clips:
				lines.append("anim\t%s\t%.3f" % [clip, player.get_animation(clip).length])
		for mesh_path: String in _mesh_paths(root, root):
			lines.append("mesh\t%s" % mesh_path)
		root.free()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("list_animations: wrote %s (%d lines)" % [OUT, lines.size()])
	quit(0)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c: Node in node.get_children():
		var p := _find_player(c)
		if p != null:
			return p
	return null


func _mesh_paths(root: Node, node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is MeshInstance3D:
		out.append(String(root.get_path_to(node)))
	for c: Node in node.get_children():
		out.append_array(_mesh_paths(root, c))
	return out
